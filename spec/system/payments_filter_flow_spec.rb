require "rails_helper"

RSpec.describe "Payments filter flow", type: :system do
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

  def sign_in
    user = create(:user, email_address: "admin@example.com")
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"
    user
  end

  it "filters to show only completed payments" do
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    loan = create(:loan, :active, :with_details, borrower: borrower, loan_number: "LOAN-PF01")
    completed = create(:payment, :completed, loan: loan, installment_number: 1, due_date: Date.current - 10.days)
    pending = create(:payment, :pending, loan: loan, installment_number: 2, due_date: Date.current + 10.days)

    sign_in
    visit payments_path(view: "completed")

    expect(page).to have_content("LOAN-PF01")
    expect(page).to have_content("Completed")
    expect(page).not_to have_content("Installment ##{pending.installment_number}")
  end

  it "navigates through the payments empty state when no payments exist" do
    sign_in
    visit payments_path

    expect(page).to have_selector("h1", text: "Payments")
    expect(page).to have_selector("h2", text: "No repayment records yet")
  end

  it "searches the payments list by borrower name" do
    matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    matching_loan = create(:loan, :active, :with_details, borrower: matching_borrower, loan_number: "LOAN-PF10")
    create(:payment, loan: matching_loan, installment_number: 1, due_date: Date.current + 5.days)
    other_borrower = create(:borrower, full_name: "Rahul Singh", phone_number: "91234 56789")
    other_loan = create(:loan, :active, :with_details, borrower: other_borrower, loan_number: "LOAN-PF11")
    create(:payment, loan: other_loan, installment_number: 1, due_date: Date.current + 5.days)

    sign_in
    visit payments_path

    fill_in "Search by loan number, borrower name, or phone", with: "Asha"
    click_button "Search payments"

    expect(page).to have_content("LOAN-PF10")
    expect(page).not_to have_content("Rahul Singh")
  end

  it "shows the filtered empty state for the upcoming view when no upcoming payments exist" do
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    loan = create(:loan, :active, :with_details, borrower: borrower, loan_number: "LOAN-PF20")
    create(:payment, :completed, loan: loan, installment_number: 1, due_date: Date.current - 5.days)

    sign_in
    visit payments_path(view: "upcoming")

    expect(page).to have_selector("h2", text: "No upcoming payments")
    expect(page).to have_link("Return to dashboard")
  end

  it "shows the overdue drill-in with a positive message when no overdue payments exist" do
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    loan = create(:loan, :active, :with_details, borrower: borrower, loan_number: "LOAN-PF30")
    create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current + 5.days)

    sign_in
    visit payments_path(view: "overdue")

    expect(page).to have_selector("h2", text: "No overdue payments")
    expect(page).to have_content("all repayments are on track")
    expect(page).to have_link("Return to dashboard")
  end
end
