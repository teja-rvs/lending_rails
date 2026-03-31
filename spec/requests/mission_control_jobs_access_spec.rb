require "rails_helper"

RSpec.describe "Mission Control Jobs access", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects unauthenticated visitors to sign in" do
    get "/jobs"

    expect(response).to redirect_to("/session/new")
  end

  it "rejects persisted non-admin operator sessions" do
    user = create(:user, email_address: "operator@example.com")
    session_record = user.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")

    set_signed_session_cookie(session_record)
    get "/jobs"

    expect(response).to redirect_to("/session/new")
    expect(Session.exists?(session_record.id)).to be(false)
  end

  it "allows signed-in admins to access Mission Control Jobs" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get "/jobs"

    expect(response).to have_http_status(:ok)
  end
end
