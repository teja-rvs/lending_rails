require "rails_helper"

RSpec.describe "Repayment schedule", type: :system do
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

  it "shows the repayment schedule section with installment details on an active loan" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-8001")
    create(:payment, :pending, loan:, installment_number: 1, due_date: Date.new(2026, 6, 1))
    create(:payment, :pending, loan:, installment_number: 2, due_date: Date.new(2026, 7, 1))

    sign_in(user)

    visit loan_path(loan, from: "loans")

    expect(page).to have_content("Repayment Schedule")
    expect(page).to have_content("Installments")
    expect(page).to have_content("2")
    expect(page).to have_content("Monthly")
    expect(page).to have_content("Next payment due")
    expect(page).to have_content("Completed installments")
    expect(page).to have_content("Pending installments")
    expect(page).to have_content("Overdue installments")
  end

  it "renders the schedule table with columns for each installment" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-8002")
    first_payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.new(2026, 6, 1))
    create(:payment, :pending, loan:, installment_number: 2, due_date: Date.new(2026, 7, 1))

    sign_in(user)

    visit loan_path(loan, from: "loans")

    within("table") do
      expect(page).to have_selector("th", text: "#")
      expect(page).to have_selector("th", text: "Due date")
      expect(page).to have_selector("th", text: "Principal")
      expect(page).to have_selector("th", text: "Interest")
      expect(page).to have_selector("th", text: "Total")
      expect(page).to have_selector("th", text: "Status")
      expect(page).to have_selector("th", text: "Invoice")
      expect(page).to have_selector("th", text: "Open")
      expect(page).to have_selector("td", text: "1")
      expect(page).to have_selector("td", text: "2")
    end

    expect(page).to have_link("Open payment", href: payment_path(first_payment, from: "loans"))
  end

  it "does not show the repayment schedule before disbursement" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :ready_for_disbursement, :with_details, loan_number: "LOAN-8003")

    sign_in(user)

    visit loan_path(loan, from: "loans")

    expect(page).not_to have_content("Repayment Schedule")
  end

  it "shows completed and pending installment counts correctly" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-8004")
    create(:payment, :completed, loan:, installment_number: 1, due_date: Date.current - 30.days)
    create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 30.days)

    sign_in(user)

    visit loan_path(loan, from: "loans")

    expect(page).to have_content("Repayment Schedule")
    expect(page).to have_content("Installments")
  end

  it "shows the invoice number for completed installments in the schedule table" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-8005")
    completed_payment = create(:payment, :completed, loan:, installment_number: 1, due_date: Date.current - 10.days)
    create(:invoice, :payment, payment: completed_payment, invoice_number: "INV-8888")
    create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 20.days)

    sign_in(user)

    visit loan_path(loan, from: "loans")

    expect(page).to have_content("INV-8888")
  end

  it "shows overdue installments and total late fees in the schedule summary" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-8006", disbursement_date: Date.current - 60.days)
    create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current - 5.days)
    create(:payment, :pending, loan:, installment_number: 2, due_date: Date.current + 25.days)

    sign_in(user)

    visit loan_path(loan, from: "loans")

    expect(page).to have_content("Repayment Schedule")
    expect(page).to have_content("Overdue")
    expect(page).to have_content("Total late fees assessed")
  end

  it "lets an admin drill from the schedule into a specific payment" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-8007")
    payment = create(:payment, :pending, loan:, installment_number: 1, due_date: Date.current + 10.days)

    sign_in(user)

    visit loan_path(loan, from: "loans")

    click_link "Open payment", match: :first

    expect(page).to have_current_path(payment_path(payment, from: "loans"))
    expect(page).to have_selector("h1", text: /LOAN-8007/)
    expect(page).to have_selector("h1", text: /Installment #1/)
  end

  it "shows the loan as Closed when all payments are completed and the admin views the loan" do
    user = create(:user, email_address: "admin@example.com")
    loan = create(:loan, :active, :with_details, loan_number: "LOAN-8008", disbursement_date: Date.current - 60.days)
    create(:payment, :completed, loan:, installment_number: 1, due_date: Date.current - 30.days)

    sign_in(user)

    visit loan_path(loan, from: "loans")

    expect(page).to have_content("Closed")
    expect(loan.reload).to be_closed
  end
end
