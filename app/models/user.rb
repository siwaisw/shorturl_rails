class User < ApplicationRecord
  has_secure_password
  has_many :short_urls, dependent: :nullify

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  before_save { self.email = email.downcase }
end
