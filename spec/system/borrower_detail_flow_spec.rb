require "rails_helper"

RSpec.describe "Borrower detail flow", type: :system do
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

  it "lets an admin open borrower detail from the borrower list and understand the next step when no history exists" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    click_link "Browse borrowers"
    click_link borrower.full_name

    expect(page).to have_current_path(borrower_path(borrower))
    expect(page).to have_selector("h1", text: "Asha Patel")
    expect(page).to have_content("Borrower details")
    expect(page).to have_content("No lending history yet")
    expect(page).to have_content("The next lending step is borrower eligibility review")
    expect(page).to have_link("Back to borrower list", href: borrowers_path)
  end

  it "lets an admin follow linked application and loan records without losing borrower context" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "in progress")
    loan = create(:loan, borrower:, loan_application: application, loan_number: "LOAN-2001", status: "active")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    click_link "Browse borrowers"
    click_link borrower.full_name
    click_link application.application_number

    expect(page).to have_current_path(loan_application_path(application))
    expect(page).to have_selector("h1", text: "APP-0101")
    expect(page).to have_content("Loan application")
    expect(page).to have_link(borrower.full_name, href: borrower_path(borrower))

    within("nav[aria-label='Breadcrumb']") do
      click_link borrower.full_name
    end
    click_link loan.loan_number

    expect(page).to have_current_path(loan_path(loan))
    expect(page).to have_selector("h1", text: "LOAN-2001")
    expect(page).to have_content("Loan")
    expect(page).to have_link(borrower.full_name, href: borrower_path(borrower))
    expect(page).to have_link(application.application_number, href: loan_application_path(application))
  end
end
