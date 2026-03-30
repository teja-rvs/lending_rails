class User < ApplicationRecord
  ADMIN_EMAIL_ADDRESSES_ENV = "ADMIN_EMAIL_ADDRESSES"

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_paper_trail skip: [ :password_digest ]

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }

  def admin?
    self.class.admin_email_addresses.include?(email_address)
  end

  def self.admin_email_addresses
    ENV.fetch(ADMIN_EMAIL_ADDRESSES_ENV, "")
      .split(",")
      .map { it.strip.downcase }
      .reject(&:empty?)
  end
end
