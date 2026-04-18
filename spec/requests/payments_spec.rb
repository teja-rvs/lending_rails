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

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash", notes: "ok" } }

      expect(response).to redirect_to(payment_path(payment, from: "payments"))
      expect(flash[:notice]).to include("LOAN-5801")
      expect(flash[:notice]).to include("#2")
      expect(payment.reload).to be_completed
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

      expect(Payments::MarkCompleted).not_to receive(:call)

      patch mark_completed_payment_path(payment),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to redirect_to(new_session_path)
      expect(payment.reload).to be_pending
      expect(Session.exists?(session_record.id)).to be(false)
    end

    it "captures the signed-in admin as PaperTrail whodunnit on the completion version" do
      user = create(:user, email_address: "admin@example.com")
      payment = create(:payment, :pending)

      sign_in_as(user)
      patch mark_completed_payment_path(payment, from: "payments"),
            params: { payment: { payment_date: Date.current, payment_mode: "cash" } }

      expect(response).to redirect_to(payment_path(payment, from: "payments"))
      expect(payment.reload).to be_completed
      expect(payment.versions.where(event: "update").last.whodunnit).to eq(user.id.to_s)
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
end
