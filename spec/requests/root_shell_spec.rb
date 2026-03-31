require 'rails_helper'

RSpec.describe 'Root shell', type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it 'renders the authenticated workspace shell content for an admin' do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get root_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Workspace | lending_rails"
    assert_select "p", text: "Authenticated workspace"
    assert_select "a[href='#{mission_control_jobs_path}']", text: "Background jobs"
    assert_select "a[href='#{rails_health_check_path}']", text: "Health check"
    assert_select "h2", text: "What this workspace is for today"
    assert_select "h2", text: "Session safety"
  end
end
