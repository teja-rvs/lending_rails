require "rails_helper"

RSpec.describe "Borrower loan applications", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects unauthenticated visitors away from borrower-scoped application creation" do
    borrower = create(:borrower)

    post borrower_loan_applications_path(borrower)

    expect(response).to redirect_to(new_session_path)
  end

  it "creates an application from an eligible borrower and redirects to the workspace" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrower_loan_applications_path(borrower)
    }.to change(LoanApplication, :count).by(1)

    loan_application = LoanApplication.order(:created_at).last

    expect(response).to redirect_to(loan_application_path(loan_application))
    expect(loan_application.status).to eq("open")
    expect(loan_application.borrower_full_name_snapshot).to eq("Asha Patel")
    expect(loan_application.borrower_phone_number_snapshot).to eq("+919876543210")
  end

  it "blocks creation when the borrower already has a blocking application" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower)
    create(:loan_application, borrower:, status: "in progress")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrower_loan_applications_path(borrower)
    }.not_to change(LoanApplication, :count)

    expect(response).to redirect_to(borrower_path(borrower))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: /wait until the current application is no longer open, in progress, or approved/i
  end

  it "blocks creation when the borrower already has a blocking loan" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower)
    create(:loan, borrower:, status: "active")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      post borrower_loan_applications_path(borrower)
    }.not_to change(LoanApplication, :count)

    expect(response).to redirect_to(borrower_path(borrower))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: /wait until the active or overdue loan is closed before starting a new application/i
  end
end
