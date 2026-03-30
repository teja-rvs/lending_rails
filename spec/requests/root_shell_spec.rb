require 'rails_helper'

RSpec.describe 'Root shell', type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it 'renders the internal application frame for an authenticated admin' do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lending_rails')
    expect(response.body).to include('Lending operations workspace')
  end
end
