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
    loan = create(
      :loan,
      borrower:,
      loan_application: application,
      loan_number: "LOAN-2001",
      status: "created",
      borrower_full_name_snapshot: "Asha Patel",
      borrower_phone_number_snapshot: borrower.phone_number_normalized
    )

    visit loan_path(loan)

    expect(page).to have_current_path(new_session_path)

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    expect(page).to have_current_path(loan_path(loan))
    expect(page).to have_selector("h1", text: "LOAN-2001")
    expect(page).to have_content("Loan")
    expect(page).to have_content("Created")
    expect(page).to have_content("Borrower snapshot")
    expect(page).to have_content("Snapshot phone number")
    expect(page).to have_content(borrower.phone_number_normalized)
    expect(page).to have_content("Next lifecycle stage")
    expect(page).to have_content("Documentation In Progress")
    expect(page).to have_link("Asha Patel", href: borrower_path(borrower))
    expect(page).to have_link("APP-0101", href: loan_application_path(application))
  end

  it "shows standalone loans without a linked application section" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Bhavya Rao", phone_number: "98765 43211")
    loan = create(
      :loan,
      borrower:,
      loan_application: nil,
      loan_number: "LOAN-2002",
      status: "closed",
      borrower_full_name_snapshot: "Bhavya Rao",
      borrower_phone_number_snapshot: borrower.phone_number_normalized
    )

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_path(loan)

    expect(page).to have_current_path(loan_path(loan))
    expect(page).to have_selector("h1", text: "LOAN-2002")
    expect(page).to have_content("Closed")
    expect(page).to have_content("Bhavya Rao")
    expect(page).to have_link("Bhavya Rao", href: borrower_path(borrower))
    expect(page).to have_selector("nav[aria-label='Breadcrumb']", text: "Bhavya Rao")
    expect(page).not_to have_content("Linked application")
  end

  it "lets an admin move from the workspace to the loans list, update details, and begin documentation" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    created_loan = create(
      :loan,
      :created,
      :with_details,
      borrower:,
      loan_number: "LOAN-5001"
    )
    create(:loan, :active, :with_details, loan_number: "LOAN-5002")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    expect(page).to have_current_path(root_path)
    click_link "Loans"

    expect(page).to have_current_path(loans_path)
    expect(page).to have_selector("h1", text: "Loans")

    click_link "Created", match: :first

    expect(page).to have_current_path(loans_path(status: "created"))
    expect(page).to have_link("LOAN-5001", href: loan_path(created_loan, from: "loans"))
    expect(page).not_to have_link("LOAN-5002")

    click_link "LOAN-5001"

    expect(page).to have_current_path(loan_path(created_loan, from: "loans"))
    within("nav[aria-label='Breadcrumb']") do
      expect(page).to have_link("Loans", href: loans_path)
    end

    fill_in "Principal amount", with: "48000"
    fill_in "Tenure (months)", with: "14"
    select "Weekly", from: "Repayment frequency"
    fill_in "Interest rate", with: "13.2500"
    fill_in "Notes", with: "Weekly repayments confirmed with the borrower."
    click_button "Save loan details"

    expect(page).to have_current_path(loan_path(created_loan, from: "loans"))
    expect(page).to have_content("Loan details saved successfully.")
    expect(page).to have_content("48000.00")
    expect(page).to have_content("14 months")
    expect(page).to have_content("Weekly")
    expect(page).to have_content("13.2500%")
    expect(page).to have_content("Weekly repayments confirmed with the borrower.")

    click_button "Begin documentation"

    expect(page).to have_current_path(loan_path(created_loan, from: "loans"))
    expect(page).to have_content("Documentation stage started for LOAN-5001.")
    expect(page).to have_content("Documentation In Progress")

    click_link "Loans"

    expect(page).to have_current_path(loans_path)
    expect(page).to have_selector("h1", text: "Loans")
  end
end
