require "rails_helper"

RSpec.describe "Password reset flow", type: :system do
  include ActiveJob::TestHelper

  before do
    driven_by(:rack_test)
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"

    perform_enqueued_jobs do
      example.run
    end
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "lets an admin request a reset, choose a new password, and sign in" do
    user = create(:user, email_address: "admin@example.com")

    visit new_session_path

    click_link "Forgot password?"

    expect(page).to have_current_path(new_password_path)
    expect(page).to have_selector("h1", text: "Forgot your password?")

    fill_in "email_address", with: user.email_address
    click_button "Email reset instructions"

    expect(page).to have_current_path(new_session_path)
    expect(page).to have_content("Password reset instructions sent")
    expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(user.email_address)

    reset_link = ActionMailer::Base.deliveries.last.body.encoded.match(%r{http://[^"\s<]+/passwords/[^"\s<]+/edit})[0]

    visit reset_link

    expect(page).to have_selector("h1", text: "Update your password")

    fill_in "password", with: "new-password123!"
    fill_in "password_confirmation", with: "new-password123!"
    click_button "Save"

    expect(page).to have_current_path(new_session_path)
    expect(page).to have_content("Password has been reset.")

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "new-password123!"
    click_button "Sign in"

    expect(page).to have_current_path(root_path)
    expect(page).to have_selector("h1", text: "Lending operations workspace")
    expect(page).to have_content("Signed in as #{user.email_address}")
  end

  it "redirects an invalid reset link back to the password request screen" do
    visit edit_password_path("invalid-token")

    expect(page).to have_current_path(new_password_path)
    expect(page).to have_content("Password reset link is invalid or has expired.")
    expect(page).to have_selector("h1", text: "Forgot your password?")
  end
end
