require "rails_helper"

RSpec.describe "Loan application workflow", type: :system do
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

  it "lets an admin move from an eligible borrower into the application workspace and see the fixed review workflow" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    click_link "Browse borrowers"
    click_link borrower.full_name
    click_button "Start application"

    loan_application = LoanApplication.order(:created_at).last

    expect(page).to have_current_path(loan_application_path(loan_application))
    expect(page).to have_selector("h1", text: loan_application.application_number)
    expect(page).to have_link(borrower.full_name, href: borrower_path(borrower))
    expect(page).to have_content("Review workflow")
    expect(page).to have_content("Current application status")
    expect(page).to have_content("Active review step")
    expect(page).to have_content("History check")
    expect(page).to have_content("Phone screening")
    expect(page).to have_content("Verification")
    expect(page).to have_content("Initialized", count: 3)

    fill_in "Requested amount", with: "45000"
    fill_in "Requested tenure (months)", with: "10"
    select "Bi-Weekly", from: "Requested repayment frequency"
    select "Interest rate", from: "Proposed interest mode"
    fill_in "Review notes", with: "Prefers a shorter repayment cycle."
    click_button "Save application details"

    expect(page).to have_current_path(loan_application_path(loan_application))
    expect(page).to have_content("Application details saved successfully.")
    expect(page).to have_content("45000.00")
    expect(page).to have_content("10 months")
    expect(page).to have_content("Bi-Weekly")
    expect(page).to have_content("Interest rate")
    expect(page).to have_content("Prefers a shorter repayment cycle.")
  end

  it "shows locked-state guidance when the application is no longer editable" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, :with_details, status: "approved")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_application_path(application)

    expect(page).to have_content("These request details can no longer be edited after a final decision.")
    expect(page).to have_field("Requested amount", with: "25000.00", disabled: true)
    expect(page).not_to have_button("Save application details")
    expect(page).to have_link(application.borrower.full_name, href: borrower_path(application.borrower))
  end
end
