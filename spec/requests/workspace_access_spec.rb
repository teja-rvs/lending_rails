require "rails_helper"

RSpec.describe "Workspace access", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects unauthenticated visitors to sign in" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "rejects valid non-admin credentials without creating a session" do
    user = create(:user, email_address: "operator@example.com")

    expect {
      post session_path, params: { email_address: user.email_address, password: "password123!" }
    }.not_to change(Session, :count)

    expect(response).to redirect_to(new_session_path)
  end

  it "clears a persisted non-admin session before protected access" do
    user = create(:user, email_address: "operator@example.com")
    session_record = user.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")

    set_signed_session_cookie(session_record)

    get root_path

    expect(response).to redirect_to(new_session_path)
    expect(Session.exists?(session_record.id)).to be(false)
  end

  it "allows an admin to sign in and access the workspace" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get root_path

    expect(response).to have_http_status(:ok)
    assert_select "h1", text: "Dashboard"
    assert_select "p", text: /#{Regexp.escape(user.email_address)}/
    assert_select "nav[aria-label='Main navigation']" do
      assert_select "button", text: "Sign out"
    end
  end
end
