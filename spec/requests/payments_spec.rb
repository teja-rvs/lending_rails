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

  it "renders a payment detail page without a completion action for signed-in admins" do
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
    assert_select "form[action*='mark_completed']", count: 0
    assert_select "button", text: /Mark.*complete/i, count: 0
    assert_select "input[type='submit']", count: 0
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
