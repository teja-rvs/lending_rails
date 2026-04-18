require "rails_helper"

RSpec.describe "Passwords", type: :request do
  include ActiveJob::TestHelper

  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  before do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "delivers a reset email with a valid token link" do
    user = create(:user)

    perform_enqueued_jobs do
      post passwords_path, params: { email_address: user.email_address }
    end

    expect(response).to redirect_to(new_session_path)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(user.email_address)
    expect(ActionMailer::Base.deliveries.last.body.encoded).to match(%r{http://example\.com/passwords/.+/edit})
  end

  it "renders the reset form without requiring an authenticated admin session" do
    user = create(:user, email_address: "admin@example.com")

    get edit_password_path(user.password_reset_token)

    expect(response).to have_http_status(:ok)
  end

  it "updates the password and invalidates existing sessions without requiring an authenticated admin session" do
    user = create(:user, email_address: "admin@example.com")
    session_record = user.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")

    patch password_path(user.password_reset_token), params: {
      password: "new-password123!",
      password_confirmation: "new-password123!"
    }

    expect(response).to redirect_to(new_session_path)
    expect(user.reload.authenticate("new-password123!")).to be_truthy
    expect(Session.exists?(session_record.id)).to be(false)
  end

  it "redirects back to the reset form when the password confirmation does not match" do
    user = create(:user, email_address: "admin@example.com")

    patch password_path(user.password_reset_token), params: {
      password: "new-password123!",
      password_confirmation: "different-password123!"
    }

    expect(response).to have_http_status(:redirect)
    expect(response.location).to match(%r{\Ahttp://www\.example\.com/passwords/.+/edit\z})

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "h1", text: "Update your password"
    assert_select "p", text: "Passwords did not match."
  end

  it "redirects invalid reset tokens back to the request form" do
    get edit_password_path("invalid-token")

    expect(response).to redirect_to(new_password_path)
  end

  it "renders the password reset request form" do
    get new_password_path

    expect(response).to have_http_status(:ok)
    assert_select "h1", text: "Forgot your password?"
    assert_select "form[action='#{passwords_path}']"
    assert_select "input[type='email'][name='email_address']"
    assert_select "input[type='submit'][value='Email reset instructions']"
  end
end
