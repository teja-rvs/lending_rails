require "rails_helper"

RSpec.describe "Loans", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects unauthenticated visitors away from the loan detail page" do
    loan = create(:loan)

    get loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "renders the linked loan lifecycle detail for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "approved")
    loan = create(
      :loan,
      borrower:,
      loan_application: application,
      loan_number: "LOAN-2001",
      status: "created",
      borrower_full_name_snapshot: "Asha Patel",
      borrower_phone_number_snapshot: borrower.phone_number_normalized
    )

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_path(loan)

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "LOAN-2001 | lending_rails"
    assert_select "h1", text: "LOAN-2001"
    assert_select "span.border-slate-200.bg-slate-100.text-slate-700", text: "Created"
    assert_select "a[href='#{borrower_path(borrower)}']", text: borrower.full_name
    assert_select "a[href='#{loan_application_path(application)}']", text: "APP-0101"
    assert_select "dt", text: "Borrower snapshot"
    assert_select "dd", text: "Asha Patel"
    assert_select "dt", text: "Snapshot phone number"
    assert_select "dd", text: borrower.phone_number_normalized
    assert_select "dt", text: "Next lifecycle stage"
    assert_select "dd", text: "Documentation In Progress"
  end
end
