require "rails_helper"

RSpec.describe "LoanApplications", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects unauthenticated visitors away from the loan application detail page" do
    application = create(:loan_application)

    get loan_application_path(application)

    expect(response).to redirect_to(new_session_path)
  end

  it "renders the linked loan application read surface for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "in progress")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_application_path(application)

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "APP-0101 | lending_rails"
    assert_select "h1", text: "APP-0101"
    assert_select "span.border-amber-200.bg-amber-50.text-amber-700", text: "In Progress"
    assert_select "a[href='#{borrower_path(borrower)}']", text: borrower.full_name
    assert_select "p", text: /minimal read surface introduced for borrower-linked navigation/i
  end
end
