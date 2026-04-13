require "rails_helper"

RSpec.describe "Loan detail flow", type: :system do
  before do
    driven_by(:rack_test)
  end

  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "returns an admin to a protected loan detail page after sign in" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "approved")
    loan = create(:loan, borrower:, loan_application: application, loan_number: "LOAN-2001", status: "active")

    visit loan_path(loan)

    expect(page).to have_current_path(new_session_path)

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    expect(page).to have_current_path(loan_path(loan))
    expect(page).to have_selector("h1", text: "LOAN-2001")
    expect(page).to have_content("Loan")
    expect(page).to have_content("This read-only loan page exists so borrower history links resolve to meaningful protected context")
    expect(page).to have_content("Active")
    expect(page).to have_link("Asha Patel", href: borrower_path(borrower))
    expect(page).to have_link("APP-0101", href: loan_application_path(application))
  end

  it "shows standalone loans without a linked application section" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Bhavya Rao", phone_number: "98765 43211")
    loan = create(:loan, borrower:, loan_application: nil, loan_number: "LOAN-2002", status: "closed")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_path(loan)

    expect(page).to have_current_path(loan_path(loan))
    expect(page).to have_selector("h1", text: "LOAN-2002")
    expect(page).to have_content("Closed")
    expect(page).to have_link("Bhavya Rao", href: borrower_path(borrower))
    expect(page).to have_selector("nav[aria-label='Breadcrumb']", text: "Bhavya Rao")
    expect(page).not_to have_content("Linked application")
  end
end
