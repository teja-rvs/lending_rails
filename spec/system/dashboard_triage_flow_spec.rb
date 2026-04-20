require "rails_helper"

RSpec.describe "Dashboard triage flow", type: :system do
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

  it "displays triage widget counts and navigates to overdue payments" do
    loan = create(:loan, :active, :with_details, disbursement_date: Date.current - 60.days)
    create(:payment, :overdue, loan: loan, installment_number: 1, due_date: Date.current - 3.days)
    create(:payment, :overdue, loan: loan, installment_number: 2, due_date: Date.current - 1.day)

    sign_in

    within("article[aria-label='Overdue payments']") do
      expect(page).to have_content("2")
      click_link "View all"
    end

    expect(page).to have_current_path(payments_path(view: "overdue"))
    expect(page).to have_selector("h1", text: "Payments")
  end

  it "displays triage widget counts and navigates to upcoming payments" do
    loan = create(:loan, :active, :with_details)
    create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current + 3.days)

    sign_in

    within("article[aria-label='Upcoming payments']") do
      expect(page).to have_content("1")
      click_link "View all"
    end

    expect(page).to have_current_path(payments_path(view: "upcoming"))
  end

  it "displays triage widget counts and navigates to open applications" do
    create(:loan_application, status: "open")
    create(:loan_application, status: "in progress")

    sign_in

    within("article[aria-label='Open applications']") do
      expect(page).to have_content("2")
      click_link "View all"
    end

    expect(page).to have_current_path(loan_applications_path(status: "open,in progress"))
  end

  it "displays triage widget counts and navigates to active loans" do
    create(:loan, :active, :with_details)
    create(:loan, :overdue, :with_details)

    sign_in

    within("article[aria-label='Active loans']") do
      expect(page).to have_content("2")
      click_link "View all"
    end

    expect(page).to have_current_path(loans_path(status: "active,overdue"))
  end

  it "displays portfolio summary with closed loans count and navigates to the list" do
    create(:loan, :closed, :with_details)

    sign_in

    within("article[aria-label='Closed loans']") do
      expect(page).to have_content("1")
      click_link "View all"
    end

    expect(page).to have_current_path(loans_path(status: "closed"))
  end

  it "displays zero counts when no data exists" do
    sign_in

    within("article[aria-label='Overdue payments']") do
      expect(page).to have_content("0")
    end

    within("article[aria-label='Upcoming payments']") do
      expect(page).to have_content("0")
    end

    within("article[aria-label='Open applications']") do
      expect(page).to have_content("0")
    end

    within("article[aria-label='Active loans']") do
      expect(page).to have_content("0")
    end
  end
end
