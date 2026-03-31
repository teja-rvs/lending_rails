require "rails_helper"

RSpec.describe AdminBootstrap, type: :service do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    original_admin_password = ENV["ADMIN_PASSWORD"]

    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com,backup@example.com"
    ENV["ADMIN_PASSWORD"] = "password123!"

    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
    ENV["ADMIN_PASSWORD"] = original_admin_password
  end

  it "creates the configured admin user idempotently" do
    expect { described_class.call }.to change(User, :count).by(1)
    expect { described_class.call }.not_to change(User, :count)

    user = User.find_by!(email_address: "admin@example.com")

    expect(user).to be_admin
    expect(user.authenticate("password123!")).to be_truthy
  end

  it "preserves an existing admin password across later seed runs" do
    described_class.call

    user = User.find_by!(email_address: "admin@example.com")
    user.update!(password: "new-password123!", password_confirmation: "new-password123!")

    ENV["ADMIN_PASSWORD"] = "different-bootstrap-password!"
    described_class.call

    user.reload

    expect(user.authenticate("new-password123!")).to be_truthy
    expect(user.authenticate("different-bootstrap-password!")).to be(false)
  end

  it "raises a clear error when no admin email address is configured" do
    ENV["ADMIN_EMAIL_ADDRESSES"] = nil

    expect { described_class.call }
      .to raise_error(
        AdminBootstrap::MissingConfigurationError,
        "Set ADMIN_EMAIL_ADDRESSES to seed the MVP admin account."
      )
  end

  it "raises a clear error when no bootstrap password is configured" do
    ENV["ADMIN_PASSWORD"] = nil

    allow(Rails.application.credentials).to receive(:dig).with(:admin, :password).and_return(nil)

    expect { described_class.call }
      .to raise_error(
        AdminBootstrap::MissingConfigurationError,
        "Set ADMIN_PASSWORD or Rails credentials admin.password before running db:seed."
      )
  end
end
