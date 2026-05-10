class User < ApplicationRecord
  PASSWORD_FORMAT = /\A(?=.*[a-zA-Z])(?=.*\d).*\z/m

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :notes, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            uniqueness: { case_sensitive: false }

  validates :password,
            length: { minimum: 8 },
            format: { with: PASSWORD_FORMAT, message: :weak_password },
            allow_blank: true
end
