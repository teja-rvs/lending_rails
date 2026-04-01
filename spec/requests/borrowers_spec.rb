require "rails_helper"

RSpec.describe "Borrowers", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects unauthenticated visitors to sign in" do
    get new_borrower_path

    expect(response).to redirect_to(new_session_path)
  end

  it "renders the borrower intake form for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get new_borrower_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Create borrower | lending_rails"
    assert_select "h1", text: "Create borrower"
    assert_select "form[action='#{borrowers_path}']" do
      assert_select "label", text: "Full name"
      assert_select "input[name='borrower[full_name]']"
      assert_select "label", text: "Phone number"
      assert_select "input[name='borrower[phone_number]']"
      assert_select "input[type='submit'][value='Create borrower']"
    end
  end

  it "creates a borrower and redirects to the confirmation page" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrowers_path, params: { borrower: { full_name: "Asha Patel", phone_number: "98765 43210" } }
    }.to change(Borrower, :count).by(1)

    borrower = Borrower.order(:created_at).last

    expect(response).to redirect_to(borrower_path(borrower))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "h1", text: "Borrower created"
    assert_select "dd", text: "Asha Patel"
    assert_select "dd", text: "+919876543210"
  end

  it "returns not found for malformed borrower ids" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get "/borrowers/not-a-uuid"

    expect(response).to have_http_status(:not_found)
  end

  it "keeps invalid phone submissions on the intake page with actionable feedback" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrowers_path, params: { borrower: { full_name: "Asha Patel", phone_number: "bad-phone" } }
    }.not_to change(Borrower, :count)

    expect(response).to have_http_status(:unprocessable_content)
    assert_select "h1", text: "Create borrower"
    assert_select "p", text: "Phone number is invalid"
    assert_select "div[role='alert'][aria-live='assertive']"
    assert_select "input[name='borrower[phone_number]'][aria-invalid='true'][aria-describedby='borrower_phone_number_hint borrower_phone_number_error']"
    assert_select "input[name='borrower[full_name]'][value='Asha Patel']"
    assert_select "input[name='borrower[phone_number]'][value='bad-phone']"
  end

  it "keeps duplicate phone submissions on the intake page with actionable feedback" do
    user = create(:user, email_address: "admin@example.com")
    create(:borrower, phone_number: "98765 43210")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrowers_path, params: { borrower: { full_name: "Asha Patel", phone_number: "+91 98765 43210" } }
    }.not_to change(Borrower, :count)

    expect(response).to have_http_status(:unprocessable_content)
    assert_select "h1", text: "Create borrower"
    assert_select "p", text: "Phone number has already been taken"
    assert_select "input[name='borrower[full_name]'][value='Asha Patel']"
    assert_select "input[name='borrower[phone_number]'][value='+91 98765 43210']"
  end
end
