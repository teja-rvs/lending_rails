require "rails_helper"

RSpec.describe "Borrower intake flow", type: :system do
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

  it "lets an admin create a borrower from the workspace" do
    user = create(:user, email_address: "admin@example.com")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    click_link "Create borrower"

    expect(page).to have_current_path(new_borrower_path)
    expect(page).to have_selector("h1", text: "Create borrower")

    fill_in "Full name", with: "Asha Patel"
    fill_in "Phone number", with: "98765 43210"
    click_button "Create borrower"

    expect(page).to have_selector("h1", text: "Asha Patel")
    expect(page).to have_content("Asha Patel")
    expect(page).to have_content("+919876543210")
    expect(page).to have_link("Back to borrower list")
  end

  it "shows a clear duplicate-phone error without losing the entered values" do
    user = create(:user, email_address: "admin@example.com")
    create(:borrower, phone_number: "98765 43210")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    visit new_borrower_path

    fill_in "Full name", with: "Asha Patel"
    fill_in "Phone number", with: "+91 98765 43210"
    click_button "Create borrower"

    expect(page).to have_selector("h1", text: "Create borrower")
    expect(page).to have_content("Phone number has already been taken")
    expect(page).to have_field("Full name", with: "Asha Patel")
    expect(page).to have_field("Phone number", with: "+91 98765 43210")
  end
end
