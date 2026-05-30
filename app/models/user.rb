class User < ApplicationRecord
  has_secure_password
  has_many :short_urls, dependent: :nullify

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  before_save   { self.email = email.downcase }
  before_create :generate_api_key

  private

  def generate_api_key
    self.api_key = SecureRandom.urlsafe_base64(32)
  end
end
