require "rails_helper"

RSpec.describe "Borrower search flow", type: :system do
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

  it "lets an admin browse borrowers, hit a filtered empty state, and recover clearly" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    click_link "Borrowers", match: :first

    expect(page).to have_current_path(borrowers_path)
    expect(page).to have_selector("h1", text: "Borrowers")
    expect(page).to have_link("Asha Patel", href: borrower_path(borrower))

    fill_in "Search by phone number or name", with: "no match"
    click_button "Search borrowers"

    expect(page).to have_current_path("#{borrowers_path}?q=no+match")
    expect(page).to have_selector("h2", text: "No borrowers match this search")
    expect(page).to have_content("Try a phone number first, adjust the name search, or create a new borrower if this person has not been added yet.")
    expect(page).to have_field("Search by phone number or name", with: "no match")
    expect(page).to have_link("Clear search", href: borrowers_path)
    expect(page).to have_link("Create borrower", href: new_borrower_path)

    click_link "Clear search", match: :first

    expect(page).to have_current_path(borrowers_path)
    expect(page).to have_link("Asha Patel", href: borrower_path(borrower))
  end
end
