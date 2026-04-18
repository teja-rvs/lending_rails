require "rails_helper"

RSpec.describe "Full lending lifecycle end-to-end", type: :system do
  include ActiveSupport::Testing::TimeHelpers

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

  def fixture_path(name)
    Rails.root.join("spec/fixtures/files/#{name}")
  end

  def sign_in(user)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"
  end

  def seed_interest_receivable(loan, interest_cents:)
    clearing = DoubleEntry.account(:disbursement_clearing, scope: loan)
    receivable = DoubleEntry.account(:loan_receivable, scope: loan)
    DoubleEntry.lock_accounts(clearing, receivable) do
      DoubleEntry.transfer(
        Money.new(interest_cents, "INR"),
        from: clearing,
        to: receivable,
        code: :disbursement,
        metadata: { loan_id: loan.id, note: "interest_seed" }
      )
    end
  end

  it "walks through the entire journey: sign in, create borrower, start application, review, approve, configure loan, document, disburse, repay, and close" do
    admin = create(:user, email_address: "admin@example.com")

    # ── Phase 1: Sign in ────────────────────────────────────────────────
    sign_in(admin)

    expect(page).to have_current_path(root_path)
    expect(page).to have_selector("h1", text: "Dashboard")

    # ── Phase 2: Create a borrower ──────────────────────────────────────
    click_link "Borrowers", match: :first
    expect(page).to have_selector("h1", text: "Borrowers")

    click_link "Create borrower", match: :first
    expect(page).to have_selector("h1", text: "Create borrower")

    fill_in "Full name", with: "Priya Sharma"
    fill_in "Phone number", with: "91234 56789"
    click_button "Create borrower"

    borrower = Borrower.find_by!(full_name: "Priya Sharma")
    expect(page).to have_current_path(borrower_path(borrower))
    expect(page).to have_selector("h1", text: "Priya Sharma")
    expect(page).to have_content("No lending history yet")
    expect(page).to have_content("Eligible for a new application")

    # ── Phase 3: Start a loan application ───────────────────────────────
    click_button "Start application"

    loan_application = LoanApplication.order(:created_at).last
    expect(page).to have_current_path(loan_application_path(loan_application))
    expect(page).to have_selector("h1", text: loan_application.application_number)
    expect(page).to have_content("Review workflow")
    expect(page).to have_content("History check")
    expect(page).to have_content("Phone screening")
    expect(page).to have_content("Verification")

    # ── Phase 4: Fill in application details ────────────────────────────
    fill_in "Requested amount", with: "24000"
    fill_in "Requested tenure (months)", with: "2"
    select "Monthly", from: "Requested repayment frequency"
    select "Interest rate", from: "Proposed interest mode"
    fill_in "Review notes", with: "Short-tenure monthly loan for business expansion."
    click_button "Save application details"

    expect(page).to have_content("Application details saved successfully.")
    expect(page).to have_content("24000.00")
    expect(page).to have_content("2 months")
    expect(page).to have_content("Monthly")

    # ── Phase 5: Progress through all three review steps ────────────────
    click_button "Approve step"
    expect(page).to have_content("Review step approved successfully.")

    click_button "Approve step"
    expect(page).to have_content("Review step approved successfully.")

    click_button "Approve step"
    expect(page).to have_content("Review step approved successfully.")

    # ── Phase 6: Approve the application (creates a loan) ──────────────
    expect(page).to have_button("Approve application")
    click_button "Approve application"

    loan = loan_application.reload.loan
    expect(loan).to be_present
    expect(page).to have_content("Application approved. Loan #{loan.loan_number} created.")
    expect(page).to have_content("Approved")
    expect(page).to have_link("View loan → #{loan.loan_number}", href: loan_path(loan))

    # ── Phase 7: Navigate to the loan workspace ─────────────────────────
    click_link "View loan → #{loan.loan_number}"

    expect(page).to have_current_path(loan_path(loan))
    expect(page).to have_selector("h1", text: loan.loan_number)
    expect(page).to have_content("Created")
    expect(page).to have_link("Priya Sharma", href: borrower_path(borrower))

    # ── Phase 8: Configure loan financial details ───────────────────────
    # With rack_test (no JS), the interest_rate field is disabled until the
    # interest_mode is persisted. First submit triggers a validation re-render
    # with the mode set, which enables the rate field for the second submit.
    fill_in "Principal amount", with: "24000"
    fill_in "Tenure (months)", with: "2"
    select "Monthly", from: "Repayment frequency"
    select "Interest rate", from: "Interest mode"
    fill_in "Notes", with: "Confirmed two monthly installments at 12% annual rate."
    click_button "Save loan details"

    expect(page).to have_content("Interest rate can't be blank")

    # Re-rendered form now has interest_mode=rate so the rate field is enabled.
    fill_in "Interest rate", with: "12.0000"
    click_button "Save loan details"

    expect(page).to have_content("Loan details saved successfully.")
    expect(page).to have_content("24000.00")
    expect(page).to have_content("2 months")
    expect(page).to have_content("12.0000%")

    # ── Phase 9: Begin documentation ────────────────────────────────────
    click_button "Begin documentation"

    expect(page).to have_content("Documentation stage started for #{loan.loan_number}.")
    expect(page).to have_content("Documentation In Progress")

    # ── Phase 10: Upload a supporting document ──────────────────────────
    within("#loan-documentation") do
      attach_file "Document file", fixture_path("sample.pdf")
      fill_in "Document name", with: "Borrower ID"
      fill_in "Description", with: "Government-issued photo ID."
      click_button "Upload document"
    end

    expect(page).to have_content("Document 'Borrower ID' uploaded successfully.")
    expect(page).to have_link("Borrower ID")

    # ── Phase 11: Complete documentation ────────────────────────────────
    click_button "Complete documentation"

    expect(page).to have_content("Documentation completed for #{loan.loan_number}. Loan is now ready for disbursement.")
    expect(page).to have_content("Ready For Disbursement")

    # ── Phase 12: Confirm disbursement ──────────────────────────────────
    expect(page).to have_button("Confirm disbursement")
    click_button "Confirm disbursement"

    expect(page).to have_content("#{loan.loan_number} has been disbursed.")
    expect(page).to have_content("Invoice number")
    expect(page).to have_content("Disbursement date")

    loan.reload
    expect(loan).to be_active
    expect(loan.payments.count).to eq(2)

    # Seed the interest receivable so repayment ledger transfers work
    total_interest_cents = loan.payments.sum(:interest_amount_cents)
    seed_interest_receivable(loan, interest_cents: total_interest_cents)

    # ── Phase 13: Verify repayment schedule ─────────────────────────────
    expect(page).to have_content("Repayment Schedule")
    expect(page).to have_content("Installments")

    within("table") do
      expect(page).to have_selector("td", text: "1")
      expect(page).to have_selector("td", text: "2")
    end

    # ── Phase 14: Complete the first payment ────────────────────────────
    first_payment = loan.payments.ordered.first
    click_link "Open payment", match: :first

    expect(page).to have_selector("h1", text: /#{loan.loan_number}/)
    expect(page).to have_selector("h1", text: /Installment #1/)
    expect(page).to have_button("Mark payment complete")

    select "Cash", from: "Payment mode"
    fill_in "Notes", with: "First installment collected in cash."
    click_button "Mark payment complete"

    expect(page).to have_content("Payment #1 for #{loan.loan_number} recorded as completed.")
    expect(first_payment.reload).to be_completed
    expect(loan.reload).to be_active

    # ── Phase 15: Return to loan and complete the final payment ─────────
    visit loan_path(loan)

    second_payment = loan.payments.ordered.last
    within("table") do
      links = all("a", text: "Open payment")
      links.last.click
    end

    expect(page).to have_selector("h1", text: /Installment #2/)

    select "Bank transfer", from: "Payment mode"
    fill_in "Notes", with: "Final installment via bank transfer."
    click_button "Mark payment complete"

    expect(page).to have_content("Payment #2 for #{loan.loan_number} recorded as completed.")
    expect(second_payment.reload).to be_completed
    expect(loan.reload).to be_closed

    # ── Phase 16: Verify the loan is closed ─────────────────────────────
    visit loan_path(loan)
    expect(page).to have_content("Closed")

    # ── Phase 17: Verify borrower detail reflects the closed loan ────────
    # The original approved application still blocks re-application per
    # business rules (approved is a blocking status).
    visit borrower_path(borrower)
    expect(page).to have_content("Priya Sharma")
    expect(page).to have_content(loan.loan_number)
    expect(page).to have_content(loan_application.application_number)

    # ── Phase 18: Verify dashboard reflects the completed lifecycle ─────
    visit root_path
    expect(page).to have_selector("h1", text: "Dashboard")

    # ── Phase 19: Sign out ──────────────────────────────────────────────
    click_button "Sign out"
    expect(page).to have_current_path(new_session_path)

    visit root_path
    expect(page).to have_current_path(new_session_path)
  end

  it "handles the overdue-then-recovery lifecycle: disburse, go overdue, pay off overdue, and close" do
    admin = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Vikram Nair", phone_number: "91234 56790")
    loan = create(
      :loan,
      :ready_for_disbursement,
      :with_details,
      borrower:,
      loan_number: "LOAN-LC-002",
      principal_amount: 24_000,
      tenure_in_months: 2,
      repayment_frequency: "monthly",
      interest_mode: "rate",
      interest_rate: BigDecimal("12.0000")
    )

    sign_in(admin)

    # ── Disburse the loan ────────────────────────────────────────────────
    visit loan_path(loan)
    click_button "Confirm disbursement"

    expect(page).to have_content("LOAN-LC-002 has been disbursed.")
    loan.reload
    expect(loan).to be_active
    expect(loan.payments.count).to eq(2)

    total_interest_cents = loan.payments.sum(:interest_amount_cents)
    seed_interest_receivable(loan, interest_cents: total_interest_cents)

    first_payment = loan.payments.ordered.first

    # ── Time-travel past the first due date to trigger overdue ───────────
    travel_to(first_payment.due_date + 3.days) do
      visit loan_path(loan)

      expect(page).to have_content("Overdue")
      expect(first_payment.reload).to be_overdue
      expect(first_payment.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      expect(loan.reload).to be_overdue
      expect(page).to have_content("Total late fees assessed")

      # ── Recover by completing the overdue payment ──────────────────────
      click_link "Open payment", match: :first

      expect(page).to have_content("Overdue")
      select "Cash", from: "Payment mode"
      fill_in "Notes", with: "Late payment collected."
      click_button "Mark payment complete"

      expect(page).to have_content("Payment #1 for LOAN-LC-002 recorded as completed.")
      expect(first_payment.reload).to be_completed
      expect(loan.reload).to be_active

      visit loan_path(loan)
      expect(page).to have_content("Active")

      # ── Complete the second payment to close ───────────────────────────
      within("table") do
        links = all("a", text: "Open payment")
        links.last.click
      end

      select "Bank transfer", from: "Payment mode"
      fill_in "Notes", with: "Final installment."
      click_button "Mark payment complete"

      second_payment = loan.payments.ordered.last
      expect(second_payment.reload).to be_completed
      expect(loan.reload).to be_closed

      visit loan_path(loan)
      expect(page).to have_content("Closed")
    end
  end

  it "covers the application rejection path and confirms the borrower can re-apply" do
    admin = create(:user, email_address: "admin@example.com")

    sign_in(admin)

    # Create a borrower
    visit new_borrower_path
    fill_in "Full name", with: "Anita Desai"
    fill_in "Phone number", with: "91234 56791"
    click_button "Create borrower"

    borrower = Borrower.find_by!(full_name: "Anita Desai")

    # Start and reject an application
    click_button "Start application"
    loan_application = LoanApplication.order(:created_at).last
    expect(page).to have_selector("h1", text: loan_application.application_number)

    click_button "Reject application"

    expect(page).to have_content("Application rejected successfully.")
    expect(page).to have_content("Rejected")
    expect(page).not_to have_button("Approve application")

    # Verify borrower is eligible again after rejection
    visit borrower_path(borrower)
    expect(page).to have_content("Eligible for a new application")
    expect(page).to have_button("Start application")

    # Start a fresh application to confirm re-application works
    click_button "Start application"
    new_application = LoanApplication.order(:created_at).last
    expect(new_application.id).not_to eq(loan_application.id)
    expect(page).to have_selector("h1", text: new_application.application_number)
  end

  it "covers the application cancellation path and confirms the borrower can re-apply" do
    admin = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Sanjay Mehta", phone_number: "91234 56792")

    sign_in(admin)

    visit borrower_path(borrower)
    click_button "Start application"

    loan_application = LoanApplication.order(:created_at).last
    expect(page).to have_selector("h1", text: loan_application.application_number)

    # Verify the borrower is blocked while application is open
    visit borrower_path(borrower)
    expect(page).to have_content("New application blocked")

    visit loan_application_path(loan_application)
    click_button "Cancel application"

    expect(page).to have_content("Application cancelled successfully.")
    expect(page).to have_content("Cancelled")

    visit borrower_path(borrower)
    expect(page).to have_content("Eligible for a new application")
  end

  it "covers loan documentation with document replacement and history preservation" do
    admin = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Meera Shah", phone_number: "91234 56793")
    loan = create(:loan, :created, :with_details, borrower:, loan_number: "LOAN-LC-DOC")

    sign_in(admin)
    visit loan_path(loan)

    click_button "Begin documentation"
    expect(page).to have_content("Documentation stage started for LOAN-LC-DOC.")

    # Upload initial document
    within("#loan-documentation") do
      attach_file "Document file", fixture_path("sample.pdf")
      fill_in "Document name", with: "Income Proof"
      fill_in "Description", with: "Salary slip for last three months."
      click_button "Upload document"
    end

    expect(page).to have_content("Document 'Income Proof' uploaded successfully.")
    expect(page).to have_link("Income Proof")

    # Replace the document
    within("article", text: "Income Proof") do
      find("summary", text: "Replace document").click

      within("details[open]") do
        attach_file "Replacement file", fixture_path("replacement.pdf")
        fill_in "Replacement document name", with: "Income Proof v2"
        fill_in "Replacement description", with: "Updated salary slip."
        click_button "Replace document"
      end
    end

    expect(page).to have_content("Document replaced. Previous version preserved in history.")
    expect(page).to have_link("Income Proof v2")

    # Verify document history
    find("summary", text: "Document history").click
    within("details[open]", text: "Document history") do
      expect(page).to have_content("Income Proof")
      expect(page).to have_content("Replaced by Income Proof v2")
    end

    # Complete documentation and verify ready state
    click_button "Complete documentation"
    expect(page).to have_content("Documentation completed for LOAN-LC-DOC.")
    expect(page).to have_content("Ready For Disbursement")
  end
end
