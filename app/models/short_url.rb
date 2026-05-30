require "uri"

class ShortUrl < ApplicationRecord
  belongs_to :user, optional: true

  # Base62 alphabet: digits, lowercase & uppercase (62 chars total)
  ALPHABET   = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".freeze
  BASE       = ALPHABET.length
  KEY_LENGTH = 7

  validates :original_url, presence: true
  validate  :original_url_must_be_valid

  before_create :set_expiry
  after_create  :assign_short_key # assigned after_create so we have the auto-increment ID to encode

  # ── Scopes used by CleanupExpiredUrlsJob ───────────────────
  scope :not_deleted,  -> { where(deleted_at: nil) }
  scope :soft_deleted, -> { where.not(deleted_at: nil) }
  scope :expired,      -> { where("expires_at < ?", Time.current) }
  # cleanable = expired AND already soft-deleted → ready for hard deletion
  scope :cleanable,    -> { expired.soft_deleted }

  # ── Read-through redirect cache ─────────────────────────────
  # Caches { id:, original_url:, expires_at: } per short_key so the hot
  # redirect path avoids a SELECT on every request (80/20 rule: 20% of URLs
  # generate 80% of traffic). The cache is busted on expiry update and deletion.
  REDIRECT_CACHE_TTL = 6.hours

  # Returns a plain-hash representation of the record, or nil on cache miss
  # if the key does not exist. skip_nil: true prevents missing keys from being
  # cached (avoids filling the cache with invalid-key misses).
  def self.fetch_for_redirect(key)
    Rails.cache.fetch("short_url:redirect:#{key}",
                      expires_in: REDIRECT_CACHE_TTL,
                      skip_nil: true) do
      record = not_deleted.find_by(short_key: key)
      record&.as_redirect_cache
    end
  end

  def as_redirect_cache
    { id: id, original_url: original_url, expires_at: expires_at }
  end

  # Bust the cache whenever expires_at is updated through the normal save path
  # (e.g. PATCH /api/v1/urls/:key). soft_delete! uses update_column which
  # bypasses callbacks, so it busts the cache explicitly (see below).
  after_commit :bust_redirect_cache, if: -> { saved_change_to_expires_at? }

  def soft_delete!
    update_column(:deleted_at, Time.current)
    bust_redirect_cache
  end

  # Encodes a positive integer into a zero-padded KEY_LENGTH Base62 string.
  # ID 12345 => "00003d7"
  def self.encode_base62(number)
    return ALPHABET[0] * KEY_LENGTH if number.zero?

    result = +""
    n = number
    while n > 0
      result.prepend(ALPHABET[n % BASE])
      n /= BASE
    end
    # If integer is greater than the length of str, returns a new String of length integer with str right justified and padded with padstr; otherwise, returns str.
    result.rjust(KEY_LENGTH, ALPHABET[0])
  end

  private

  def bust_redirect_cache
    Rails.cache.delete("short_url:redirect:#{short_key}") if short_key.present?
    Rails.logger.debug { "[Cache] Busted short_key=#{short_key}" }
  end

  def original_url_must_be_valid
    return if original_url.blank?

    uri = URI.parse(original_url)
    unless uri.is_a?(URI::HTTP) && uri.host.present?
      errors.add(:original_url, "must be a valid HTTP or HTTPS URL")
    end
  rescue URI::InvalidURIError
    errors.add(:original_url, "must be a valid HTTP or HTTPS URL")
  end

  def set_expiry
    self.expires_at ||= 1.year.from_now
  end

  def assign_short_key
    update_column(:short_key, self.class.encode_base62(id))
  end
end
