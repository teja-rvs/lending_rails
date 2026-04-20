require "rails_helper"

RSpec.describe "Loans index search flow", type: :system do
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

  it "searches the loans list by loan number and narrows the results" do
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    matching = create(:loan, :active, :with_details, borrower: borrower, loan_number: "LOAN-S001")
    other_borrower = create(:borrower, full_name: "Rahul Singh", phone_number: "91234 56789")
    create(:loan, :active, :with_details, borrower: other_borrower, loan_number: "LOAN-S002")

    sign_in
    visit loans_path

    expect(page).to have_content("LOAN-S001")
    expect(page).to have_content("LOAN-S002")

    fill_in "Search by loan number, borrower name, or phone", with: "LOAN-S001"
    click_button "Search loans"

    expect(page).to have_content("LOAN-S001")
    expect(page).not_to have_content("LOAN-S002")
  end

  it "searches the loans list by borrower name" do
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    create(:loan, :active, :with_details, borrower: borrower, loan_number: "LOAN-S003")
    other_borrower = create(:borrower, full_name: "Rahul Singh", phone_number: "91234 56789")
    create(:loan, :active, :with_details, borrower: other_borrower, loan_number: "LOAN-S004")

    sign_in
    visit loans_path

    fill_in "Search by loan number, borrower name, or phone", with: "Asha"
    click_button "Search loans"

    expect(page).to have_content("LOAN-S003")
    expect(page).not_to have_content("LOAN-S004")
  end

  it "shows the empty state when no loans exist" do
    sign_in
    visit loans_path

    expect(page).to have_selector("h2", text: "No loans found")
  end

  it "shows filtered empty state when search returns no results" do
    create(:loan, :active, :with_details, loan_number: "LOAN-S010")

    sign_in
    visit loans_path

    fill_in "Search by loan number, borrower name, or phone", with: "nonexistent"
    click_button "Search loans"

    expect(page).to have_content("No loans match")
    expect(page).to have_link("Clear filters")
  end
end
