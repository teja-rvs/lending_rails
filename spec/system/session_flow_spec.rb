require "rails_helper"

RSpec.describe "Session flow", type: :system do
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

  it "lets an admin sign in to the workspace and sign out again" do
    user = create(:user, email_address: "admin@example.com")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    expect(page).to have_current_path(root_path)
    expect(page).to have_selector("h1", text: "Dashboard")
    expect(page).to have_content(user.email_address)
    expect(page).to have_button("Sign out")

    click_button "Sign out"

    expect(page).to have_current_path(new_session_path)
    expect(page).to have_selector("h1", text: "Lending operations workspace")
    expect(page).to have_button("Sign in")

    visit root_path

    expect(page).to have_current_path(new_session_path)
  end

  it "keeps invalid credentials on the sign-in screen with a clear error" do
    user = create(:user, email_address: "admin@example.com")

    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "wrong-password"
    click_button "Sign in"

    expect(page).to have_current_path(new_session_path)
    expect(page).to have_content("Try another email address or password.")
    expect(page).to have_selector("h1", text: "Lending operations workspace")
  end

  it "returns an admin to the protected jobs page that prompted sign in" do
    user = create(:user, email_address: "admin@example.com")

    visit "/jobs"

    expect(page).to have_current_path(new_session_path)

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123!"
    click_button "Sign in"

    expect(page).to have_current_path(%r{\A/jobs/?\z})
  end
end
