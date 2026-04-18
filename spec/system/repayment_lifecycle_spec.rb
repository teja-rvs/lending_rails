require "rails_helper"

RSpec.describe "Repayment lifecycle end-to-end", type: :system do
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

  it "disburses a loan, generates a schedule, completes all payments, and closes the loan" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Priya Sharma", phone_number: "91234 56789")
    loan = create(
      :loan,
      :ready_for_disbursement,
      :with_details,
      borrower:,
      loan_number: "LOAN-E2E-001",
      principal_amount: 24_000,
      tenure_in_months: 2,
      repayment_frequency: "monthly",
      interest_mode: "rate",
      interest_rate: BigDecimal("12.0000")
    )

    sign_in(user)

    visit loan_path(loan, from: "loans")
    click_button "Confirm disbursement"

    expect(page).to have_content("LOAN-E2E-001 has been disbursed.")
    expect(page).to have_content("Repayment Schedule")
    expect(page).to have_content("Installments")

    loan.reload
    expect(loan).to be_active
    expect(loan.payments.count).to eq(2)

    total_interest_cents = loan.payments.sum(:interest_amount_cents)
    seed_interest_receivable(loan, interest_cents: total_interest_cents)

    within("table") do
      expect(page).to have_selector("td", text: "1")
      expect(page).to have_selector("td", text: "2")
    end

    first_payment = loan.payments.ordered.first
    click_link "Open payment", match: :first

    expect(page).to have_selector("h1", text: /LOAN-E2E-001/)
    expect(page).to have_selector("h1", text: /Installment #1/)
    expect(page).to have_button("Mark payment complete")

    select "Cash", from: "Payment mode"
    fill_in "Notes", with: "First installment collected."
    click_button "Mark payment complete"

    expect(page).to have_content("Payment #1 for LOAN-E2E-001 recorded as completed.")
    expect(first_payment.reload).to be_completed
    expect(loan.reload).to be_active

    visit loan_path(loan, from: "loans")

    second_payment = loan.payments.ordered.last
    within("table") do
      links = all("a", text: "Open payment")
      links.last.click
    end

    expect(page).to have_selector("h1", text: /Installment #2/)

    select "Bank transfer", from: "Payment mode"
    fill_in "Notes", with: "Final installment via bank transfer."
    click_button "Mark payment complete"

    expect(page).to have_content("Payment #2 for LOAN-E2E-001 recorded as completed.")
    expect(second_payment.reload).to be_completed
    expect(loan.reload).to be_closed

    visit loan_path(loan, from: "loans")
    expect(page).to have_content("Closed")
  end

  it "derives overdue status and late fees when visiting a loan with a past-due payment" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Vikram Nair", phone_number: "91234 56790")
    loan = create(
      :loan,
      :ready_for_disbursement,
      :with_details,
      borrower:,
      loan_number: "LOAN-E2E-002",
      principal_amount: 24_000,
      tenure_in_months: 2,
      repayment_frequency: "monthly",
      interest_mode: "rate",
      interest_rate: BigDecimal("12.0000")
    )

    sign_in(user)

    visit loan_path(loan, from: "loans")
    click_button "Confirm disbursement"

    expect(page).to have_content("LOAN-E2E-002 has been disbursed.")
    loan.reload
    expect(loan).to be_active
    expect(loan.payments.count).to eq(2)

    first_payment = loan.payments.ordered.first

    travel_to(first_payment.due_date + 2.days) do
      visit loan_path(loan, from: "loans")

      expect(page).to have_content("Overdue")
      expect(first_payment.reload).to be_overdue
      expect(first_payment.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      expect(loan.reload).to be_overdue
      expect(page).to have_content("Total late fees assessed")
    end
  end

  it "recovers an overdue loan to active after completing the overdue payment" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Anita Desai", phone_number: "91234 56791")
    loan = create(
      :loan,
      :ready_for_disbursement,
      :with_details,
      borrower:,
      loan_number: "LOAN-E2E-003",
      principal_amount: 24_000,
      tenure_in_months: 2,
      repayment_frequency: "monthly",
      interest_mode: "rate",
      interest_rate: BigDecimal("12.0000")
    )

    sign_in(user)

    visit loan_path(loan, from: "loans")
    click_button "Confirm disbursement"

    loan.reload
    first_payment = loan.payments.ordered.first

    total_interest_cents = loan.payments.sum(:interest_amount_cents)
    seed_interest_receivable(loan, interest_cents: total_interest_cents)

    travel_to(first_payment.due_date + 3.days) do
      visit loan_path(loan, from: "loans")
      expect(loan.reload).to be_overdue

      click_link "Open payment", match: :first

      expect(page).to have_content("Overdue")
      expect(page).to have_button("Mark payment complete")

      select "Cash", from: "Payment mode"
      fill_in "Notes", with: "Late payment collected."
      click_button "Mark payment complete"

      expect(page).to have_content("Payment #1 for LOAN-E2E-003 recorded as completed.")
        expect(first_payment.reload).to be_completed
        expect(loan.reload).to be_active

        visit loan_path(loan, from: "loans")
        expect(page).to have_content("Active")
        expect(page).to have_content("Overdue installments")
        expect(page).to have_content("0")
    end
  end

  it "shows overdue payments in the payments list overdue filter after derivation" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Sanjay Mehta", phone_number: "91234 56792")
    loan = create(
      :loan,
      :ready_for_disbursement,
      :with_details,
      borrower:,
      loan_number: "LOAN-E2E-004",
      principal_amount: 24_000,
      tenure_in_months: 2,
      repayment_frequency: "monthly",
      interest_mode: "rate",
      interest_rate: BigDecimal("12.0000")
    )

    sign_in(user)

    visit loan_path(loan, from: "loans")
    click_button "Confirm disbursement"

    loan.reload
    first_payment = loan.payments.ordered.first

    travel_to(first_payment.due_date + 1.day) do
      visit payments_path(view: "overdue")

      expect(page).to have_content("LOAN-E2E-004")
      expect(first_payment.reload).to be_overdue
    end
  end
end
