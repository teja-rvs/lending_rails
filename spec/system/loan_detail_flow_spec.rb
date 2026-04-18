require "rails_helper"

RSpec.describe "Loan detail flow", type: :system do
  before do
    driven_by(:rack_test)
  end

  def fixture_path(name)
    Rails.root.join("spec/fixtures/files/#{name}")
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
    within("nav[aria-label='Main navigation']") { click_link "Loans" }

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

    within("nav[aria-label='Main navigation']") { click_link "Loans" }

    expect(page).to have_current_path(loans_path)
    expect(page).to have_selector("h1", text: "Loans")
  end

  it "lets an admin upload, replace, and preserve document history during documentation" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Meera Shah", phone_number: "98765 43212")
    loan = create(
      :loan,
      :created,
      :with_details,
      borrower:,
      loan_number: "LOAN-5003"
    )

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_path(loan, from: "loans")

    click_button "Begin documentation"

    expect(page).to have_content("Documentation stage started for LOAN-5003.")
    expect(page).to have_content("Documentation In Progress")

    within("#loan-documentation") do
      attach_file "Document file", fixture_path("sample.pdf")
      fill_in "Document name", with: "Borrower ID"
      fill_in "Description", with: "Government issued ID."
      click_button "Upload document"
    end

    expect(page).to have_content("Document 'Borrower ID' uploaded successfully.")
    expect(page).to have_link("Borrower ID")
    expect(page).to have_content("admin@example.com")

    within("article", text: "Borrower ID") do
      find("summary", text: "Replace document").click

      within("details[open]") do
        attach_file "Replacement file", fixture_path("replacement.pdf")
        fill_in "Replacement document name", with: "Borrower ID v2"
        fill_in "Replacement description", with: "Updated document scan."
        click_button "Replace document"
      end
    end

    expect(page).to have_content("Document replaced. Previous version preserved in history.")
    expect(page).to have_link("Borrower ID v2")

    find("summary", text: "Document history").click

    within("details[open]", text: "Document history") do
      expect(page).to have_content("Borrower ID")
      expect(page).to have_content("Replaced by Borrower ID v2")
    end

    click_button "Complete documentation"

    expect(page).to have_content("Documentation completed for LOAN-5003. Loan is now ready for disbursement.")
    expect(page).to have_content("Ready For Disbursement")
    expect(page).to have_field("Document name")
  end

  it "lets an admin confirm disbursement and then shows the locked invoice summary" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Kiran Rao", phone_number: "98765 43213")
    loan = create(
      :loan,
      :ready_for_disbursement,
      :with_details,
      borrower:,
      loan_number: "LOAN-5004"
    )

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_path(loan, from: "loans")

    expect(page).to have_selector("section#loan-disbursement")
    expect(page).to have_button("Confirm disbursement")
    expect(page).to have_content("This loan is ready for the guarded disbursement handoff.")

    click_button "Confirm disbursement"

    invoice = loan.reload.disbursement_invoice

    expect(page).to have_current_path(loan_path(loan, from: "loans"))
    expect(page).to have_content("LOAN-5004 has been disbursed.")
    expect(page).to have_content("This loan has been disbursed.")
    expect(page).to have_content("Invoice number")
    expect(page).to have_content(invoice.invoice_number)
    expect(page).to have_content("Disbursement date")
    expect(page).to have_content(Date.current.to_fs(:long))
    expect(page).to have_content("Disbursed amount")
    expect(page).to have_content("Locked")
    expect(page).to have_content("loan is now active")
    expect(page).not_to have_button("Confirm disbursement")
    expect(page).not_to have_button("Save loan details")
  end

  it "lets an admin recover from blocked disbursement readiness after filling missing details" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Ritu Sen", phone_number: "98765 43214")
    loan = create(
      :loan,
      :ready_for_disbursement,
      borrower:,
      loan_number: "LOAN-5005",
      interest_mode: "rate"
    )

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_path(loan, from: "loans")

    expect(page).to have_content("Disbursement is currently blocked.")
    expect(page).to have_content("Disbursement is blocked because Required financial details are incomplete.")
    expect(page).to have_content("Complete the missing pre-disbursement loan details before attempting disbursement.")
    expect(page).to have_button("Proceed toward disbursement", disabled: true)
    expect(page).not_to have_button("Confirm disbursement")

    fill_in "Principal amount", with: "52500"
    fill_in "Tenure (months)", with: "18"
    select "Bi-Weekly", from: "Repayment frequency"
    fill_in "Interest rate", with: "11.7500"
    fill_in "Notes", with: "Updated after final affordability review."
    click_button "Save loan details"

    expect(page).to have_current_path(loan_path(loan, from: "loans"))
    expect(page).to have_content("Loan details saved successfully.")
    expect(page).to have_content("This loan is ready for the guarded disbursement handoff.")
    expect(page).to have_button("Proceed toward disbursement")
    expect(page).to have_button("Confirm disbursement")

    click_button "Proceed toward disbursement"

    expect(page).to have_current_path(loan_path(loan, from: "loans"))
    expect(page).to have_content("Disbursement readiness confirmed for LOAN-5005.")

    click_button "Confirm disbursement"

    expect(page).to have_current_path(loan_path(loan, from: "loans"))
    expect(page).to have_content("LOAN-5005 has been disbursed.")
    expect(page).to have_content("Locked")
    expect(loan.reload).to be_active
  end

  it "lets an admin disburse a loan that uses total interest amount details" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Neha Iyer", phone_number: "98765 43215")
    loan = create(
      :loan,
      :ready_for_disbursement,
      :with_total_interest_details,
      borrower:,
      loan_number: "LOAN-5006"
    )

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_path(loan, from: "loans")

    expect(page).to have_content("Total interest amount")
    expect(page).to have_content("8000.00")
    expect(page).to have_button("Confirm disbursement")
    expect(page).not_to have_content("12.5000%")

    click_button "Confirm disbursement"

    invoice = loan.reload.disbursement_invoice

    expect(page).to have_current_path(loan_path(loan, from: "loans"))
    expect(page).to have_content("LOAN-5006 has been disbursed.")
    expect(page).to have_content(invoice.invoice_number)
    expect(page).to have_content("Total interest amount")
    expect(page).to have_content("8000.00")
    expect(page).to have_content("Locked")
    expect(page).not_to have_button("Confirm disbursement")
    expect(page).not_to have_button("Save loan details")
    expect(loan).to be_active
  end

  it "lets an admin recover from blocked fixed-interest readiness by entering total interest amount" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Sana Kapoor", phone_number: "98765 43216")
    loan = create(
      :loan,
      :ready_for_disbursement,
      borrower:,
      loan_number: "LOAN-5007",
      principal_amount: 45_000,
      tenure_in_months: 12,
      repayment_frequency: "monthly",
      interest_mode: "total_interest_amount",
      total_interest_amount: nil
    )

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit loan_path(loan, from: "loans")

    expect(page).to have_content("Disbursement is currently blocked.")
    expect(page).to have_content("Total interest amount can't be blank.")
    expect(page).to have_button("Proceed toward disbursement", disabled: true)
    expect(page).not_to have_button("Confirm disbursement")

    fill_in "Total interest amount", with: "9100"
    fill_in "Notes", with: "Fixed interest amount finalized during closing review."
    click_button "Save loan details"

    expect(page).to have_current_path(loan_path(loan, from: "loans"))
    expect(page).to have_content("Loan details saved successfully.")
    expect(page).to have_content("9100.00")
    expect(page).to have_content("This loan is ready for the guarded disbursement handoff.")
    expect(page).to have_button("Confirm disbursement")

    click_button "Confirm disbursement"

    invoice = loan.reload.disbursement_invoice

    expect(page).to have_current_path(loan_path(loan, from: "loans"))
    expect(page).to have_content("LOAN-5007 has been disbursed.")
    expect(page).to have_content(invoice.invoice_number)
    expect(page).to have_content("9100.00")
    expect(page).to have_content("Locked")
    expect(page).not_to have_button("Confirm disbursement")
    expect(loan).to be_active
  end
end
