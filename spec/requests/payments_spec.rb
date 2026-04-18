require "rails_helper"

RSpec.describe "Payments", type: :request do
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

  # Seed the loan_receivable account so RecordRepayment can transfer from it.
  # Mirrors the post-disbursement ledger state without running the full disburse service.
  def seed_receivable_for(loan, amount_cents: loan.principal_amount_cents || 4_500_000)
    clearing = DoubleEntry.account(:disbursement_clearing, scope: loan)
    receivable = DoubleEntry.account(:loan_receivable, scope: loan)
    DoubleEntry.lock_accounts(clearing, receivable) do
      DoubleEntry.transfer(
        Money.new(amount_cents, "INR"),
        from: clearing,
        to: receivable,
        code: :disbursement,
        metadata: { loan_id: loan.id }
      )
    end
  end

  it "redirects unauthenticated visitors away from the payments list" do
    get payments_path

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from a payment detail page" do
    payment = create(:payment)

    get payment_path(payment)

    expect(response).to redirect_to(new_session_path)
  end

  it "renders the neutral empty state for signed-in admins with no payments" do
    user = create(:user, email_address: "admin@example.com")

    sign_in_as(user)
    get payments_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Payments | lending_rails"
    assert_select "h1", text: "Payments"
    assert_select "h2", text: "No repayment records yet"
  end

  it "lists payments with filter and drill links for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    loan = create(:loan, :active, :with_details, borrower:, loan_number: "LOAN-5501")
    payment = create(:payment, loan:, installment_number: 1, due_date: Date.new(2026, 6, 1))

    sign_in_as(user)
    get payments_path

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{payment_path(payment, from: "payments")}']", text: /LOAN-5501/
    assert_select "td", text: /Asha Patel/
    assert_select "span.border-slate-200.bg-slate-100.text-slate-700", text: "Pending"
  end

  it "renders a constrained list when view=upcoming is applied and matching payments exist" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    loan = create(:loan, :active, :with_details, borrower:, loan_number: "LOAN-5901")
    pending = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.new(2026, 6, 1))
    completed = create(:payment, :completed, loan:, installment_number: 2, due_date: Date.new(2026, 5, 1))

    sign_in_as(user)
    get payments_path, params: { view: "upcoming" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{payment_path(pending, from: "payments")}']", text: /LOAN-5901/
    assert_select "a[href='#{payment_path(completed, from: "payments")}']", count: 0
    assert_select "h2", text: "No payments match the current filters", count: 0
  end

  it "renders the filtered-empty amber card with a clear-filters CTA when a filter matches nothing" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-5601")
    create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current + 5.days)

    sign_in_as(user)
    get payments_path, params: { view: "overdue" }

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "No payments match the current filters"
    assert_select "a[href='#{payments_path}']", text: "Clear filters"
  end

  it "renders a payment detail page with the guarded completion form for pending payments" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    loan = create(:loan, :active, :with_details, borrower:, loan_number: "LOAN-5701")
    payment = create(:payment, loan:, installment_number: 3, due_date: Date.new(2026, 6, 20))

    sign_in_as(user)
    get payment_path(payment, from: "payments")

    expect(response).to have_http_status(:ok)
    assert_select "h1", text: /LOAN-5701/
    assert_select "h1", text: /Installment #3/
    assert_select "a[href='#{loan_path(loan)}']", text: "LOAN-5701"
    assert_select "a[href='#{borrower_path(borrower)}']", text: "Asha Patel"
    assert_select "form[action='#{mark_completed_payment_path(payment, from: 'payments')}']"
    assert_select "input[type='submit'][data-turbo-confirm*='lock'][value='Mark payment complete']"
  end

  it "renders the locked summary card for completed payments without form inputs" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-5702")
    payment = create(:payment, :completed, loan:, installment_number: 1, due_date: Date.current, notes: "Paid in full")

    sign_in_as(user)
    get payment_path(payment, from: "payments")

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "Payment completed"
    assert_select "form[action*='mark_completed']", count: 0
    assert_select "input[type='submit']", count: 0
  end

  describe "PATCH /payments/:id/mark_completed" do
    it "redirects unauthenticated visitors to the sign-in page" do
      payment = create(:payment, :pending)

      patch mark_completed_payment_path(payment), params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to redirect_to(new_session_path)
    end

    it "marks a pending payment complete and redirects with a success flash" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, loan_number: "LOAN-5801")
      payment = create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 3.days)
      seed_receivable_for(loan)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash", notes: "ok" } }

      expect(response).to redirect_to(payment_path(payment, from: "payments"))
      expect(flash[:notice]).to include("LOAN-5801")
      expect(flash[:notice]).to include("#2")
      expect(payment.reload).to be_completed
    end

    it "closes the loan when the final remaining payment is completed without changing the success flash" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, loan_number: "LOAN-5801A")
      create(:payment, :completed, loan:, installment_number: 1, due_date: Date.current - 20.days)
      final_payment = create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 3.days)
      seed_receivable_for(loan, amount_cents: final_payment.total_amount_cents)

      sign_in_as(user)
      patch mark_completed_payment_path(final_payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to redirect_to(payment_path(final_payment, from: "payments"))
      expect(flash[:notice]).to eq("Payment ##{final_payment.installment_number} for #{loan.loan_number} recorded as completed.")
      expect(final_payment.reload).to be_completed
      expect(loan.reload).to be_closed
    end

    it "creates a payment invoice and posts ledger lines on successful completion" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details)
      payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current + 3.days)
      seed_receivable_for(loan)

      sign_in_as(user)

      expect {
        patch mark_completed_payment_path(payment, from: "payments"),
              params: { payment: { payment_date: Date.current, payment_mode: "cash" } }
      }.to change { Invoice.payment.where(payment_id: payment.id).count }.from(0).to(1)
        .and change { DoubleEntry::Line.where(account: "repayment_received", scope: loan.id).count }.by(1)
        .and change { DoubleEntry::Line.where(account: "loan_receivable", scope: loan.id).count }.by(1)

      expect(response).to redirect_to(payment_path(payment, from: "payments"))
      expect(payment.reload).to be_completed
    end

    it "renders the invoice number on the payment detail page after completion" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details)
      payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current + 3.days)
      seed_receivable_for(loan)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/INV-\d{4,}/)
    end

    it "does not create invoice or ledger lines when completion is blocked (missing payment_date)" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details)
      payment = create(:payment, :pending, loan:)

      sign_in_as(user)

      invoice_count_before = Invoice.count
      lines_before = DoubleEntry::Line.where(account: "repayment_received").count

      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: "", payment_mode: "cash" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(payment.reload).to be_pending
      expect(Invoice.count).to eq(invoice_count_before)
      expect(DoubleEntry::Line.where(account: "repayment_received").count).to eq(lines_before)
    end

    it "re-renders the detail page with the blocked alert when payment_date is missing" do
      user = create(:user, email_address: "admin@example.com")
      payment = create(:payment, :pending)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: "", payment_mode: "cash", notes: "draft note" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash.now[:alert]).to eq("Payment date is required.")
      expect(response.body).to include("Payment date is required.")
      expect(response.body).to include("draft note")
      assert_select "form[action='#{mark_completed_payment_path(payment, from: 'payments')}']"
      expect(payment.reload).to be_pending
    end

    it "re-renders the detail page with the blocked alert for unsupported payment modes" do
      user = create(:user, email_address: "admin@example.com")
      payment = create(:payment, :pending)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "wire_transfer" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash.now[:alert]).to eq("wire_transfer is not a supported payment mode.")
    end

    it "re-renders with the idempotency alert when completing twice" do
      user = create(:user, email_address: "admin@example.com")
      payment = create(:payment, :completed)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash.now[:alert]).to include("already been completed")
    end

    it "preserves the from=loans breadcrumb through the redirect" do
      user = create(:user, email_address: "admin@example.com")
      payment = create(:payment, :pending)
      seed_receivable_for(payment.loan)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "loans"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to redirect_to(payment_path(payment, from: "loans"))
    end

    it "rejects a signed-in non-admin session before invoking the service" do
      non_admin = create(:user, email_address: "operator@example.com")
      session_record = non_admin.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")
      set_signed_session_cookie(session_record)
      payment = create(:payment, :pending)

      expect(Loans::RecordRepayment).not_to receive(:call)

      patch mark_completed_payment_path(payment),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to redirect_to(new_session_path)
      expect(payment.reload).to be_pending
      expect(Session.exists?(session_record.id)).to be(false)
    end

    it "captures the signed-in admin as PaperTrail whodunnit on the completion version" do
      user = create(:user, email_address: "admin@example.com")
      payment = create(:payment, :pending)
      seed_receivable_for(payment.loan)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to redirect_to(payment_path(payment, from: "payments"))
      expect(payment.reload).to be_completed
      expect(payment.versions.where(event: "update").last.whodunnit).to eq(user.id.to_s)
    end

    it "captures the signed-in admin as PaperTrail whodunnit on the invoice creation version" do
      user = create(:user, email_address: "admin@example.com")
      payment = create(:payment, :pending)
      seed_receivable_for(payment.loan)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      invoice = payment.reload.invoice
      expect(invoice).to be_present
      create_version = invoice.versions.where(event: "create").first
      expect(create_version).to be_present
      expect(create_version.whodunnit).to eq(user.id.to_s)
    end
  end

  it "uses the loan breadcrumb when the admin drills in from a loan workspace" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-5801")
    payment = create(:payment, loan:, installment_number: 2, due_date: Date.new(2026, 6, 20))

    sign_in_as(user)
    get payment_path(payment, from: "loans")

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loans_path}']", text: "Loans"
    assert_select "a[href='#{loan_path(loan, from: "loans")}']", text: "LOAN-5801"
  end

  describe "overdue derivation freshness (Story 5.5)" do
    it "marks a pending-past-due payment overdue and applies the late fee on GET /payments/:id" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, disbursement_date: Date.current - 60.days)
      payment = create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current - 3.days)

      sign_in_as(user)
      get payment_path(payment, from: "payments")

      expect(response).to have_http_status(:ok)
      expect(payment.reload).to be_overdue
      expect(payment.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      assert_select "dt", text: "Late fee"
      assert_select "dd", text: formatted_money(Payments::LateFeePolicy.flat_fee_cents)
    end

    it "derives overdue payments on GET /payments index" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, disbursement_date: Date.current - 60.days)
      payment = create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current - 2.days)

      sign_in_as(user)

      expect { get payments_path }.to change { Payment.where(status: "overdue").count }.by(1)
      expect(payment.reload).to be_overdue
    end

    it "shows the derived overdue payment on the view=overdue filter" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, loan_number: "LOAN-5910", disbursement_date: Date.current - 60.days)
      payment = create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current - 2.days)

      sign_in_as(user)
      get payments_path, params: { view: "overdue" }

      expect(response).to have_http_status(:ok)
      expect(payment.reload).to be_overdue
      assert_select "a[href='#{payment_path(payment, from: "payments")}']"
    end

    it "back-flips the loan from overdue to active when the last overdue payment is completed" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :overdue, :with_details, disbursement_date: Date.current - 60.days)
      overdue_payment = create(:payment, :overdue, loan: loan, installment_number: 1, due_date: Date.current - 5.days)
      create(:payment, :pending, loan: loan, installment_number: 2, due_date: Date.current + 20.days)
      seed_receivable_for(loan)

      sign_in_as(user)
      patch mark_completed_payment_path(overdue_payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to redirect_to(payment_path(overdue_payment, from: "payments"))
      expect(overdue_payment.reload).to be_completed
      expect(loan.reload).to be_active
    end

    it "renders successfully for a completed payment whose loan closes during the refresh" do
      user = create(:user, email_address: "admin@example.com")
      loan = create(:loan, :active, :with_details, disbursement_date: Date.current - 60.days)
      payment = create(:payment, :completed, loan: loan, installment_number: 1, due_date: Date.current - 5.days)

      sign_in_as(user)
      get payment_path(payment, from: "payments")

      expect(response).to have_http_status(:ok)
      expect(payment.reload).to be_completed
      expect(loan.reload).to be_closed
    end
  end
end
