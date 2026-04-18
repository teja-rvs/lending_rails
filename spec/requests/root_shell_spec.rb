require 'rails_helper'

RSpec.describe 'Root shell', type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it 'renders the authenticated dashboard for an admin' do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get root_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Dashboard | lending_rails"
    assert_select "h1", text: "Dashboard"
    assert_select "nav[aria-label='Main navigation']"
  end
end
