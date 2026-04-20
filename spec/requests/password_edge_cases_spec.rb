require "rails_helper"

RSpec.describe "Password edge cases", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects PATCH with an invalid token to the request form" do
    patch password_path("invalid-token"), params: {
      password: "new-password123!",
      password_confirmation: "new-password123!"
    }

    expect(response).to redirect_to(new_password_path)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Password reset link is invalid or has expired."
  end

  it "always redirects after requesting a reset for an unknown email without leaking existence" do
    post passwords_path, params: { email_address: "nobody@example.com" }

    expect(response).to redirect_to(new_session_path)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: /Password reset instructions sent/
  end
end
