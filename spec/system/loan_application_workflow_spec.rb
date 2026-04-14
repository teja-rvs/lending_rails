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

  def sign_in_as(user)
    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"
  end

  def create_completed_review_workflow(loan_application)
    create(:review_step, :history_check, loan_application:, status: "approved")
    create(:review_step, :phone_screening, loan_application:, status: "approved")
    create(:review_step, :verification, loan_application:, status: "approved")
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

  it "lets an admin reach the applications list from the workspace and keeps that context in the detail breadcrumb" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "in progress")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    click_link "Applications"

    expect(page).to have_current_path(loan_applications_path)
    expect(page).to have_selector("h1", text: "Applications")

    click_link application.application_number

    expect(page).to have_current_path(loan_application_path(application, from: "applications"))
    within("nav[aria-label='Breadcrumb']") do
      expect(page).to have_link("Applications", href: loan_applications_path)
      expect(page).to have_link(borrower.full_name, href: borrower_path(borrower))
    end
  end

  it "lets an admin filter the applications list by status and search by borrower name" do
    user = create(:user, email_address: "admin@example.com")
    matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    matching = create(:loan_application, borrower: matching_borrower, application_number: "APP-0101", status: "approved")
    create(:loan_application, application_number: "APP-0102", status: "open")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_applications_path
    click_link "Approved"

    expect(page).to have_current_path(loan_applications_path(status: "approved"))
    expect(page).to have_link(matching.application_number, href: loan_application_path(matching, from: "applications"))
    expect(page).not_to have_content("APP-0102")

    fill_in "Search by application number or borrower name", with: "Asha"
    click_button "Search applications"

    expect(page).to have_current_path(loan_applications_path, ignore_query: true)
    expect(URI.decode_www_form(URI.parse(page.current_url).query).to_h).to include(
      "q" => "Asha",
      "status" => "approved"
    )
    expect(page).to have_link(matching.application_number, href: loan_application_path(matching, from: "applications"))
    expect(page).not_to have_content("APP-0102")
  end

  it "lets an admin approve an application once every review step is approved" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, status: "in progress")
    create_completed_review_workflow(application)

    sign_in_as(user)
    visit loan_application_path(application)

    expect(page).to have_button("Approve application")
    expect(page).to have_button("Reject application")
    expect(page).to have_button("Cancel application")

    click_button "Approve application"

    expect(page).to have_current_path(loan_application_path(application))
    loan = application.reload.loan

    expect(page).to have_content("Application approved. Loan #{loan.loan_number} created.")
    expect(page).to have_content("This application is now locked for further review and detail changes.")
    expect(page).to have_content("Approved")
    expect(page).to have_content("A loan has been created from this approved application")
    expect(page).to have_link("View loan → #{loan.loan_number}", href: loan_path(loan))
    expect(page).not_to have_button("Approve application")
    expect(page).not_to have_button("Reject application")
    expect(page).not_to have_button("Cancel application")

    click_link "View loan → #{loan.loan_number}"

    expect(page).to have_current_path(loan_path(loan))
    expect(page).to have_content("Created")
    expect(page).to have_content("Documentation In Progress")
    expect(page).to have_link(application.application_number, href: loan_application_path(application))

    click_link application.application_number

    expect(page).to have_current_path(loan_application_path(application))
    expect(page).to have_link("View loan → #{loan.loan_number}", href: loan_path(loan))
  end

  it "lets an admin reject an application during review" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, status: "in progress")
    create(:review_step, :history_check, loan_application: application, status: "approved")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    sign_in_as(user)
    visit loan_application_path(application)

    expect(page).not_to have_button("Approve application")
    expect(page).to have_button("Reject application")
    expect(page).to have_button("Cancel application")

    click_button "Reject application"

    expect(page).to have_current_path(loan_application_path(application))
    expect(page).to have_content("Application rejected successfully.")
    expect(page).to have_content("Rejected")
    expect(page).not_to have_button("Approve application")
    expect(page).not_to have_button("Reject application")
    expect(page).not_to have_button("Cancel application")
  end

  it "lets an admin cancel an application during review" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, status: "open")
    create(:review_step, :history_check, loan_application: application, status: "initialized")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    sign_in_as(user)
    visit loan_application_path(application)

    expect(page).not_to have_button("Approve application")
    expect(page).to have_button("Reject application")
    expect(page).to have_button("Cancel application")

    click_button "Cancel application"

    expect(page).to have_current_path(loan_application_path(application))
    expect(page).to have_content("Application cancelled successfully.")
    expect(page).to have_content("Cancelled")
    expect(page).not_to have_button("Approve application")
    expect(page).not_to have_button("Reject application")
    expect(page).not_to have_button("Cancel application")
  end

  it "shows decision notes for applications that already have a final decision" do
    user = create(:user, email_address: "admin@example.com")
    application = create(
      :loan_application,
      status: "rejected",
      decision_notes: "Borrower could not provide the required verification."
    )
    create(:review_step, :history_check, loan_application: application, status: "approved")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    sign_in_as(user)
    visit loan_application_path(application)

    expect(page).to have_content("Borrower could not provide the required verification.")
    expect(page).not_to have_button("Approve application")
    expect(page).not_to have_button("Reject application")
    expect(page).not_to have_button("Cancel application")
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

  it "shows borrower lending context within the application workspace" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "in progress")
    prior_application = create(:loan_application, borrower:, application_number: "APP-0009", status: "approved")
    loan = create(:loan, borrower:, loan_application: prior_application, loan_number: "LOAN-0003", status: "active")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_application_path(application)

    within("#borrower-lending-context") do
      expect(page).to have_content("Borrower lending context")
      expect(page).to have_content("Borrower has active lending work")
      expect(page).to have_link(prior_application.application_number, href: loan_application_path(prior_application))
      expect(page).to have_link(loan.loan_number, href: loan_path(loan))
      expect(page).to have_link("View full borrower profile", href: borrower_path(borrower))
      expect(page).not_to have_link(application.application_number, href: loan_application_path(application))
    end
  end

  it "shows a borrower-history empty state and lets the admin navigate to the borrower profile" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "open")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_application_path(application)

    within("#borrower-lending-context") do
      expect(page).to have_content("No prior lending history for this borrower beyond the current application")
      click_link "View full borrower profile"
    end

    expect(page).to have_current_path(borrower_path(borrower))
    expect(page).to have_selector("h1", text: borrower.full_name)
  end

  it "lets an admin progress the current active review step from the application workspace" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, status: "open")
    create(:review_step, :history_check, loan_application: application, status: "initialized")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_application_path(application)
    click_button "Approve step"

    expect(page).to have_current_path(loan_application_path(application))
    expect(page).to have_content("Review step approved successfully.")
    expect(page).to have_content("Phone screening")
    expect(page).to have_content("In Progress")
  end

  it "shows blocked-state guidance when the current step is waiting for details" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, status: "open")
    create(:review_step, :history_check, loan_application: application, status: "initialized")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_application_path(application)
    click_button "Request details"

    expect(page).to have_current_path(loan_application_path(application))
    expect(page).to have_content("Review step marked as waiting for details.")
    expect(page).to have_content("waiting for details before review can continue")
    expect(page).to have_content("History check")
  end
end
