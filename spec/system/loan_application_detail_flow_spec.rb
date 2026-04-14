require "rails_helper"

RSpec.describe "Loan application detail flow", type: :system do
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

  it "returns an admin to a protected loan application detail page after sign in" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "open")

    visit loan_application_path(application)

    expect(page).to have_current_path(new_session_path)

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    expect(page).to have_current_path(loan_application_path(application))
    expect(page).to have_selector("h1", text: "APP-0101")
    expect(page).to have_content("Loan application")
    expect(page).to have_content("Review workflow")
    expect(page).to have_content("Current request summary")
    expect(page).to have_link("Asha Patel", href: borrower_path(borrower))
    expect(page).to have_content("History check")
    expect(page).to have_content("Phone screening")
    expect(page).to have_content("Verification")
  end

  it "preserves the applications-list context when sign in starts from a protected application detail deep link" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Bhavya Rao", phone_number: "98765 43211")
    application = create(:loan_application, borrower:, application_number: "APP-0102", status: "in progress")

    visit loan_application_path(application, from: "applications")

    expect(page).to have_current_path(new_session_path)

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    expect(page).to have_current_path(loan_application_path(application, from: "applications"))
    expect(page).to have_selector("h1", text: "APP-0102")
    within("nav[aria-label='Breadcrumb']") do
      expect(page).to have_link("Applications", href: loan_applications_path)
      expect(page).to have_link("Borrowers", href: borrowers_path)
      expect(page).to have_link("Bhavya Rao", href: borrower_path(borrower))
    end
  end
end
