class AdminBootstrap < ApplicationService
  class MissingConfigurationError < StandardError; end

  ADMIN_PASSWORD_ENV = "ADMIN_PASSWORD"

  def call
    user = User.find_or_initialize_by(email_address: admin_email_address)

    assign_password(user) if user.new_record?
    user.save! if user.new_record? || user.changed?

    user
  end

  private
    def admin_email_address
      User.admin_email_addresses.first.presence || raise(
        MissingConfigurationError,
        "Set #{User::ADMIN_EMAIL_ADDRESSES_ENV} to seed the MVP admin account."
      )
    end

    def admin_password
      ENV[ADMIN_PASSWORD_ENV].presence || Rails.application.credentials.dig(:admin, :password).presence || raise(
        MissingConfigurationError,
        "Set #{ADMIN_PASSWORD_ENV} or Rails credentials admin.password before running db:seed."
      )
    end

    def assign_password(user)
      user.password = admin_password
      user.password_confirmation = admin_password
    end
end
