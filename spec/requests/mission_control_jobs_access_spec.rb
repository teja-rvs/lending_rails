require "rails_helper"

RSpec.describe "Mission Control Jobs access", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "rejects signed-in non-admin operators" do
    user = create(:user, email_address: "operator@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get "/jobs"

    expect(response).to redirect_to(root_path)
  end
end
