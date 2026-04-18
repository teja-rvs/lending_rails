require "rails_helper"

RSpec.describe "Payment workflow", type: :system do
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

  def sign_in(user)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"
  end

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

  it "lets an admin browse payments, drill into a pending payment, and mark it completed" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    loan = create(:loan, :active, :with_details, borrower:, loan_number: "LOAN-7001")
    payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current + 10.days)
    seed_receivable_for(loan)

    sign_in(user)

    click_link "Payments"

    expect(page).to have_current_path(payments_path)
    expect(page).to have_selector("h1", text: "Payments")
    expect(page).to have_content("Asha Patel")
    expect(page).to have_content("LOAN-7001")

    click_link "LOAN-7001", match: :first

    expect(page).to have_selector("h1", text: /LOAN-7001/)
    expect(page).to have_selector("h1", text: /Installment #1/)
    expect(page).to have_content("Pending")
    expect(page).to have_button("Mark payment complete")

    select "Cash", from: "Payment mode"
    fill_in "Notes", with: "Paid in office."
    click_button "Mark payment complete"

    expect(page).to have_content("Payment #1 for LOAN-7001 recorded as completed.")
    expect(page).to have_content("Payment completed")
    expect(page).not_to have_button("Mark payment complete")
    expect(page).to have_content("admin@example.com")
    expect(payment.reload).to be_completed
  end

  it "shows overdue status and late fee when a payment is past due" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-7002", disbursement_date: Date.current - 60.days)
    payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current - 5.days)

    sign_in(user)

    visit payment_path(payment, from: "payments")

    expect(page).to have_selector("h1", text: /LOAN-7002/)
    expect(page).to have_content("Overdue")
    expect(payment.reload).to be_overdue
    expect(payment.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
  end

  it "filters the payment list by the overdue view" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-7003", disbursement_date: Date.current - 60.days)
    overdue_payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current - 3.days)
    create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 20.days)

    sign_in(user)

    visit payments_path(view: "overdue")

    expect(page).to have_selector("h1", text: "Payments")
    expect(page).to have_content("LOAN-7003")
    expect(overdue_payment.reload).to be_overdue
  end

  it "shows the filtered-empty state when no payments are overdue" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-7004")
    create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current + 30.days)

    sign_in(user)

    visit payments_path(view: "overdue")

    expect(page).to have_content("No overdue payments")
    expect(page).to have_link("Clear filters")
  end

  it "lets an admin mark an overdue payment as completed and resolves the loan back to active" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :overdue, :with_details, loan_number: "LOAN-7005", disbursement_date: Date.current - 60.days)
    overdue_payment = create(:payment, :overdue, loan:, installment_number: 1, due_date: Date.current - 5.days)
    create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 20.days)
    seed_receivable_for(loan)

    sign_in(user)

    visit payment_path(overdue_payment, from: "payments")

    expect(page).to have_content("Overdue")
    expect(page).to have_button("Mark payment complete")

    select "Cash", from: "Payment mode"
    click_button "Mark payment complete"

    expect(page).to have_content("Payment #1 for LOAN-7005 recorded as completed.")
    expect(overdue_payment.reload).to be_completed
    expect(loan.reload).to be_active
  end

  it "closes the loan when the final payment is completed" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-7006")
    create(:payment, :completed, loan:, installment_number: 1, due_date: Date.current - 20.days)
    final_payment = create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 3.days)
    seed_receivable_for(loan, amount_cents: final_payment.total_amount_cents)

    sign_in(user)

    visit payment_path(final_payment, from: "payments")

    select "Cash", from: "Payment mode"
    click_button "Mark payment complete"

    expect(page).to have_content("Payment #2 for LOAN-7006 recorded as completed.")
    expect(final_payment.reload).to be_completed
    expect(loan.reload).to be_closed
  end

  it "re-renders the form with an error when payment_date is missing" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-7007")
    payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current + 5.days)

    sign_in(user)

    visit payment_path(payment, from: "payments")

    fill_in "Payment date", with: ""
    select "Cash", from: "Payment mode"
    click_button "Mark payment complete"

    expect(page).to have_content("Payment date is required.")
    expect(page).to have_button("Mark payment complete")
    expect(payment.reload).to be_pending
  end

  it "navigates from loan workspace payments breadcrumb correctly" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-7008")
    payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current + 5.days)

    sign_in(user)

    visit payment_path(payment, from: "loans")

    expect(page).to have_link("Loans")
    expect(page).to have_link("LOAN-7008")
  end
end
