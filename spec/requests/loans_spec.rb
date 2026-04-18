require "rails_helper"

RSpec.describe "Loans", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123!" }
  end

  def formatted_money(cents)
    ApplicationController.helpers.humanized_money_with_symbol(Money.new(cents, "INR"))
  end

  it "redirects unauthenticated visitors away from the loans list" do
    get loans_path

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from the loan detail page" do
    loan = create(:loan)

    get loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from loan updates" do
    loan = create(:loan)

    patch loan_path(loan), params: {
      loan: {
        principal_amount: "45000",
        tenure_in_months: "12",
        repayment_frequency: "monthly",
        interest_mode: "rate",
        interest_rate: "12.5000"
      }
    }

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from begin documentation" do
    loan = create(:loan)

    patch begin_documentation_loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from complete documentation" do
    loan = create(:loan, :documentation_in_progress)

    patch complete_documentation_loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from attempt disbursement" do
    loan = create(:loan, :ready_for_disbursement, :with_details)

    patch attempt_disbursement_loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "renders an empty loans list state for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")

    sign_in_as(user)
    get loans_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Loans | lending_rails"
    assert_select "h1", text: "Loans"
    assert_select "h2", text: "No loans found"
  end

  it "filters the loans list by lifecycle state" do
    user = create(:user, email_address: "admin@example.com")
    matching = create(:loan, :created, loan_number: "LOAN-0101")
    create(:loan, :active, loan_number: "LOAN-0102")

    sign_in_as(user)
    get loans_path, params: { status: "created" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_path(matching, from: "loans")}']", text: matching.loan_number
    assert_select "a", text: "LOAN-0102", count: 0
  end

  it "searches the loans list by borrower name" do
    user = create(:user, email_address: "admin@example.com")
    matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    matching = create(:loan, borrower: matching_borrower, loan_number: "LOAN-0111")
    other_borrower = create(:borrower, full_name: "Rahul Singh", phone_number: "91234 56789")
    create(:loan, borrower: other_borrower, loan_number: "LOAN-0222")

    sign_in_as(user)
    get loans_path, params: { q: "Asha" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_path(matching, from: "loans")}']", text: matching.loan_number
    assert_select "td", text: "Rahul Singh", count: 0
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

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "LOAN-2001 | lending_rails"
    assert_select "h1", text: "LOAN-2001"
    assert_select "a[href='#{loans_path}']", text: "Loans"
    assert_select "span.border-slate-200.bg-slate-100.text-slate-700", text: "Created"
    assert_select "a[href='#{borrower_path(borrower)}']", text: borrower.full_name
    assert_select "a[href='#{loan_application_path(application)}']", text: "APP-0101"
    assert_select "h2", text: "Disbursement readiness"
    assert_select "h2", text: "Loan documentation"
    assert_select "h2", text: "Pre-disbursement loan details"
    assert_select "h2", text: "Current loan summary"
    assert_select "input[type='submit'][value='Save loan details']"
    assert_select "form.button_to[action='#{begin_documentation_loan_path(loan, from: "loans")}']"
    assert_select "button[disabled='disabled']", text: "Proceed toward disbursement"
  end

  it "saves editable pre-disbursement details for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, loan_number: "LOAN-3001")

    sign_in_as(user)
    patch loan_path(loan), params: {
      from: "loans",
      loan: {
        principal_amount: "45000",
        tenure_in_months: "10",
        repayment_frequency: "bi-weekly",
        interest_mode: "rate",
        interest_rate: "12.5000",
        notes: "Prefers a shorter repayment cycle."
      }
    }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Loan details saved successfully."
    assert_select "dd", text: "45000.00"
    assert_select "dd", text: "10 months"
    assert_select "dd", text: "Bi-Weekly"
    assert_select "dd", text: "Interest rate"
    assert_select "dd", text: "12.5000%"
    assert_select "dd", text: "Prefers a shorter repayment cycle."
  end

  it "keeps invalid pre-disbursement updates on the loan workspace with actionable feedback" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, loan_number: "LOAN-3002")

    sign_in_as(user)
    patch loan_path(loan), params: {
      loan: {
        principal_amount: "",
        tenure_in_months: "",
        repayment_frequency: "daily",
        interest_mode: "rate",
        interest_rate: ""
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    assert_select "h1", text: "LOAN-3002"
    assert_select "h2", text: "Please correct the highlighted loan details."
    assert_select "p", text: "Principal amount can't be blank"
    assert_select "p", text: "Tenure in months can't be blank"
    assert_select "p", text: "Repayment frequency is not included in the list"
    assert_select "p", text: "Interest rate can't be blank"
  end

  it "blocks updates after disbursement and explains the lifecycle boundary" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-3003")

    sign_in_as(user)
    patch loan_path(loan), params: {
      loan: {
        principal_amount: "99999",
        tenure_in_months: "2",
        repayment_frequency: "weekly",
        interest_mode: "total_interest_amount",
        total_interest_amount: "1200"
      }
    }

    expect(response).to redirect_to(loan_path(loan))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "These loan details can no longer be edited after disbursement."
    assert_select "dd", text: "45000.00"
    assert_select "input[type='submit'][value='Save loan details']", count: 0
  end

  it "lets a signed-in admin begin documentation from the created state" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, :with_details, loan_number: "LOAN-4001")

    sign_in_as(user)
    patch begin_documentation_loan_path(loan), params: { from: "loans" }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Documentation stage started for LOAN-4001."
    assert_select "dd", text: "Documentation In Progress"
    expect(loan.reload).to be_documentation_in_progress
  end

  it "guards begin documentation when the state transition is invalid" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-4002")

    sign_in_as(user)
    patch begin_documentation_loan_path(loan)

    expect(response).to redirect_to(loan_path(loan))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "This loan cannot begin documentation from its current state."
    expect(loan.reload).to be_active
  end

  it "lets a signed-in admin complete documentation from documentation_in_progress" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :documentation_in_progress, :with_details, loan_number: "LOAN-4003")

    sign_in_as(user)
    patch complete_documentation_loan_path(loan), params: { from: "loans" }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Documentation completed for LOAN-4003. Loan is now ready for disbursement."
    assert_select "dd", text: "Ready For Disbursement"
    expect(loan.reload).to be_ready_for_disbursement
  end

  it "shows an enabled proceed action when a loan is ready for disbursement and details are complete" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :ready_for_disbursement, :with_details, loan_number: "LOAN-4003A")

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "form.button_to[action='#{attempt_disbursement_loan_path(loan, from: "loans")}']"
    assert_select "button[disabled='disabled']", text: "Proceed toward disbursement", count: 0
  end

  it "shows the disbursement summary instead of readiness after the loan is already active" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-4003AA")

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "Disbursement"
    assert_select "h2", text: "Disbursement readiness", count: 0
    assert_select "p", text: /This loan has been disbursed/
    assert_select "form.button_to[action='#{attempt_disbursement_loan_path(loan, from: "loans")}']", count: 0
  end

  it "blocks a disbursement attempt on the server and explains what is missing" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, loan_number: "LOAN-4003B")

    sign_in_as(user)
    patch attempt_disbursement_loan_path(loan), params: { from: "loans" }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: /Disbursement is blocked because/
    assert_select "p", text: /Complete the missing pre-disbursement loan details/
  end

  it "guards complete documentation when the state transition is invalid" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, :with_details, loan_number: "LOAN-4004")

    sign_in_as(user)
    patch complete_documentation_loan_path(loan)

    expect(response).to redirect_to(loan_path(loan))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "This loan cannot complete documentation from its current state."
    expect(loan.reload).to be_created
  end

  it "redirects unauthenticated visitors away from disburse" do
    loan = create(:loan, :ready_for_disbursement, :with_details)

    patch disburse_loan_path(loan)

    expect(response).to redirect_to(new_session_path)
  end

  it "disburses a ready loan and shows the confirmation" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :ready_for_disbursement, :with_details, loan_number: "LOAN-5001")

    sign_in_as(user)
    patch disburse_loan_path(loan), params: { from: "loans" }

    expect(response).to redirect_to(loan_path(loan, from: "loans"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: /LOAN-5001 has been disbursed/
    expect(loan.reload).to be_active
    expect(loan.disbursement_date).to eq(Date.current)
    expect(loan.invoices.disbursement.count).to eq(1)
  end

  it "blocks server-side disbursement when the loan is not ready" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, :with_details, loan_number: "LOAN-5002")

    sign_in_as(user)
    patch disburse_loan_path(loan)

    expect(response).to redirect_to(loan_path(loan))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: /cannot be disbursed/
    expect(loan.reload).to be_created
  end

  it "shows the disbursement section with confirm button on a ready-for-disbursement loan" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :ready_for_disbursement, :with_details, loan_number: "LOAN-5003")

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "section#loan-disbursement"
    assert_select "form.button_to[action='#{disburse_loan_path(loan, from: "loans")}']"
    assert_select "button", text: "Confirm disbursement"
  end

  it "does not show the disbursement section on pre-ready loans" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :created, :with_details, loan_number: "LOAN-5004")

    sign_in_as(user)
    get loan_path(loan)

    expect(response).to have_http_status(:ok)
    assert_select "section#loan-disbursement", count: 0
  end

  it "shows disbursement summary after disbursement and locks loan details" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :ready_for_disbursement, :with_details, loan_number: "LOAN-5005")

    sign_in_as(user)
    patch disburse_loan_path(loan, from: "loans")
    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "section#loan-disbursement"
    assert_select "h2", text: "Disbursement readiness", count: 0
    assert_select "h2", text: "Loan details (locked)"
    assert_select "input[type='submit'][value='Save loan details']", count: 0
    assert_select "form.button_to[action='#{disburse_loan_path(loan, from: "loans")}']", count: 0
  end

  it "renders invoice details in the disbursement summary for active loans" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-5006")
    invoice = create(
      :invoice,
      loan: loan,
      invoice_number: "INV-9001",
      amount_cents: loan.principal_amount_cents,
      issued_on: loan.disbursement_date
    )

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "section#loan-disbursement"
    assert_select "h2", text: "Disbursement"
    assert_select "dt", text: "Invoice number"
    assert_select "dd", text: invoice.invoice_number
    assert_select "dt", text: "Disbursed amount"
    expect(response.body).to match(/45,?000\.00/)
    assert_select "p", text: /Locked/
    assert_select "input[type='submit'][value='Save loan details']", count: 0
    assert_select "form.button_to[action='#{disburse_loan_path(loan, from: "loans")}']", count: 0
  end

  it "renders the repayment schedule section for active loans with generated payments" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-5006A")
    first_payment = create(:payment, loan:, installment_number: 1, due_date: Date.new(2026, 5, 16))
    create(:payment, loan:, installment_number: 2, due_date: Date.new(2026, 6, 16))

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "Repayment Schedule"
    assert_select "dt", text: "Installments"
    assert_select "dd", text: "2"
    assert_select "th", text: "#"
    assert_select "th", text: "Due date"
    assert_select "th", text: "Principal"
    assert_select "th", text: "Interest"
    assert_select "th", text: "Total"
    assert_select "th", text: "Status"
    assert_select "th", text: "Invoice"
    assert_select "th", text: "Open"
    assert_select "td", text: "1"
    assert_select "td", text: "2"
    assert_select "span.border-slate-200.bg-slate-100.text-slate-700", text: "Pending", count: 2
    assert_select "dt", text: "Next payment due"
    assert_select "dt", text: "Completed installments"
    assert_select "dt", text: "Pending installments"
    assert_select "dt", text: "Overdue installments"
    assert_select "a[href='#{payment_path(first_payment, from: "loans")}']", text: "Open payment"
  end

  it "renders the invoice number in the repayment schedule for completed installments" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-5006C")
    completed_payment = create(:payment, :completed, loan:, installment_number: 1, due_date: Date.current - 10.days)
    create(:invoice, :payment, payment: completed_payment, invoice_number: "INV-9000")
    create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 20.days)

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("INV-9000")
    assert_select "td", text: "—"
  end

  it "does not render the repayment schedule section before disbursement" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :ready_for_disbursement, :with_details, loan_number: "LOAN-5006B")

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "Repayment Schedule", count: 0
  end

  it "renders the fixed total-interest summary for active loans after disbursement" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_total_interest_details, loan_number: "LOAN-5007")
    invoice = create(
      :invoice,
      loan: loan,
      invoice_number: "INV-9002",
      amount_cents: loan.principal_amount_cents,
      issued_on: loan.disbursement_date
    )

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "section#loan-disbursement"
    assert_select "dd", text: invoice.invoice_number
    assert_select "dt", text: "Interest mode"
    assert_select "dd", text: "Total interest amount"
    assert_select "dt", text: "Interest details"
    assert_select "dd", text: "8000.00"
    assert_select "input[type='submit'][value='Save loan details']", count: 0
    expect(response.body).not_to include("12.5000%")
  end

  it "renders a blocked readiness summary for fixed-interest loans missing total interest amount" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(
      :loan,
      :ready_for_disbursement,
      loan_number: "LOAN-5008",
      principal_amount: 45_000,
      tenure_in_months: 12,
      repayment_frequency: "monthly",
      interest_mode: "total_interest_amount",
      total_interest_amount: nil
    )

    sign_in_as(user)
    get loan_path(loan, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "Disbursement readiness"
    assert_select "p", text: /Disbursement is blocked because Required financial details are incomplete/
    assert_select "p", text: /Complete the missing pre-disbursement loan details before attempting disbursement\./
    assert_select "h3", text: "Required financial details are complete"
    assert_select "p", text: "Total interest amount can't be blank."
    assert_select "button[disabled='disabled']", text: "Proceed toward disbursement"
    assert_select "button", text: "Confirm disbursement", count: 0
  end

  describe "overdue derivation freshness on loan show" do
    it "renders an active loan as Overdue when a pending-past-due payment exists" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, loan_number: "LOAN-5950", disbursement_date: Date.current - 60.days)
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current - 2.days)

      sign_in_as(user)
      get loan_path(loan, from: "loans")

      expect(response).to have_http_status(:ok)
      assert_select "span", text: "Overdue"
      assert_select "dd", text: "1"
      expect(loan.reload).to be_overdue
    end

    it "shows total late fees assessed on the loan repayment summary when a late fee is derived" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, loan_number: "LOAN-5950A", disbursement_date: Date.current - 60.days)
      payment = create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current - 2.days)

      sign_in_as(user)
      get loan_path(loan, from: "loans")

      expect(response).to have_http_status(:ok)
      expect(payment.reload).to be_overdue
      expect(payment.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      assert_select "dt", text: "Total late fees assessed"
      assert_select "dd", text: formatted_money(Payments::LateFeePolicy.flat_fee_cents)
      assert_select "a[href='#{payment_path(payment, from: "loans")}']", text: "Open payment"
    end

    it "renders the loan as Closed when all payments have been completed" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, loan_number: "LOAN-5951A", disbursement_date: Date.current - 60.days)
      create(:payment, :completed, loan: loan, installment_number: 1, due_date: Date.current - 30.days)

      sign_in_as(user)
      get loan_path(loan, from: "loans")

      expect(response).to have_http_status(:ok)
      expect(loan.reload).to be_closed
      assert_select "span", text: "Closed"
    end

    it "leaves an active loan as Active when only future-dated payments exist" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, loan_number: "LOAN-5951")
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current + 10.days)

      sign_in_as(user)
      get loan_path(loan, from: "loans")

      expect(response).to have_http_status(:ok)
      expect(loan.reload).to be_active
    end

    it "renders successfully for a ready_for_disbursement loan with no payments" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :ready_for_disbursement, :with_details, loan_number: "LOAN-5952")

      sign_in_as(user)
      get loan_path(loan, from: "loans")

      expect(response).to have_http_status(:ok)
      expect(loan.reload).to be_ready_for_disbursement
    end

    it "renders successfully for a closed loan without mutating state" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, loan_number: "LOAN-5953", disbursement_date: Date.current - 90.days)
      loan.update_columns(status: "closed")

      sign_in_as(user)
      get loan_path(loan, from: "loans")

      expect(response).to have_http_status(:ok)
      expect(loan.reload).to be_closed
    end
  end
end
