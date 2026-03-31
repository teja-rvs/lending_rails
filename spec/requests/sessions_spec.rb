require "rails_helper"

RSpec.describe "Sessions", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "renders a focused login screen with product identity and recovery actions" do
    get new_session_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Admin sign in | lending_rails"
    assert_select "section h1", text: "Lending operations workspace"
    assert_select "p", text: "lending_rails"
    assert_select "form[action='#{session_url}']" do
      assert_select "label", text: "Email address"
      assert_select "input[name='email_address'][type='email'][placeholder='admin@example.com']"
      assert_select "label", text: "Password"
      assert_select "input[name='password'][type='password'][maxlength='72']"
      assert_select "input[type='submit'][value='Sign in']"
    end
    assert_select "a[href='#{new_password_path}']", text: "Forgot password?"
  end

  it "authenticates an admin and redirects into the workspace" do
    user = create(:user, email_address: "admin@example.com")

    post "/session", params: { email_address: user.email_address, password: "password123!" }

    expect(response).to redirect_to(root_url)
    expect(Session.where(user: user).count).to eq(1)
  end

  it "redirects an admin back to the protected page that prompted sign in" do
    user = create(:user, email_address: "admin@example.com")

    get "/jobs"

    expect(response).to redirect_to("http://www.example.com/session/new")

    post "/session", params: { email_address: user.email_address, password: "password123!" }

    expect(response).to redirect_to("http://www.example.com/jobs/")
    expect(Session.where(user: user).count).to eq(1)
  end

  it "signs an admin out and requires authentication again for the workspace" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    session_record = Session.find_by!(user: user)

    expect {
      delete session_path
    }.to change(Session, :count).by(-1)

    expect(response).to redirect_to(new_session_path)
    expect(Session.exists?(session_record.id)).to be(false)

    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "returns invalid credentials to the login screen with one clear error message" do
    user = create(:user, email_address: "admin@example.com")

    expect {
      post session_path, params: { email_address: user.email_address, password: "wrong-password" }
    }.not_to change(Session, :count)

    expect(response).to redirect_to(new_session_path)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Admin sign in | lending_rails"
    assert_select "div.border-b.border-rose-200.bg-rose-50 p", text: "Try another email address or password.", count: 1
    assert_select "section h1", text: "Lending operations workspace"
  end
end
