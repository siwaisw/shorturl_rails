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
