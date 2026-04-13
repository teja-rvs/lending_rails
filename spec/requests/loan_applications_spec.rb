require "rails_helper"

RSpec.describe "LoanApplications", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  it "redirects unauthenticated visitors away from the loan application detail page" do
    application = create(:loan_application)

    get loan_application_path(application)

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from loan application updates" do
    application = create(:loan_application)

    patch loan_application_path(application), params: {
      loan_application: {
        requested_amount: "25000",
        requested_tenure_in_months: "12",
        requested_repayment_frequency: "monthly",
        proposed_interest_mode: "rate"
      }
    }

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from review-step progression" do
    application = create(:loan_application)
    review_step = create(:review_step, :history_check, loan_application: application, status: "initialized")

    patch approve_loan_application_review_step_path(application, review_step)

    expect(response).to redirect_to(new_session_path)
  end

  it "renders the canonical application workspace and review workflow for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "in progress")
    create(
      :review_step,
      loan_application: application,
      step_key: "history_check",
      position: 1,
      status: "approved"
    )
    create(
      :review_step,
      loan_application: application,
      step_key: "phone_screening",
      position: 2,
      status: "initialized"
    )
    create(
      :review_step,
      loan_application: application,
      step_key: "verification",
      position: 3,
      status: "initialized"
    )

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_application_path(application)

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "APP-0101 | lending_rails"
    assert_select "h1", text: "APP-0101"
    assert_select "span.border-amber-200.bg-amber-50.text-amber-700", text: "In Progress"
    assert_select "a[href='#{borrower_path(borrower)}']", text: borrower.full_name
    assert_select "h2", text: "Review workflow"
    assert_select "dt", text: "Active review step"
    assert_select "dd", text: "Phone screening"
    assert_select "li", text: /History check/
    assert_select "li", text: /Phone screening/
    assert_select "li", text: /Verification/
    assert_select "h2", text: "Pre-decision application details"
    assert_select "label", text: "Requested amount"
    assert_select "label", text: "Requested tenure (months)"
    assert_select "label", text: "Requested repayment frequency"
    assert_select "label", text: "Proposed interest mode"
    assert_select "input[type='submit'][value='Save application details']"
  end

  it "backfills missing review steps on the application show page without duplicating them" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "open")

    post session_path, params: { email_address: user.email_address, password: "password123!" }

    expect {
      get loan_application_path(application)
    }.to change(ReviewStep, :count).by(3)

    expect(response).to have_http_status(:ok)
    expect(application.reload.review_steps.pluck(:step_key)).to eq(
      %w[history_check phone_screening verification]
    )

    expect {
      get loan_application_path(application)
    }.not_to change(ReviewStep, :count)
  end

  it "shows that there is no active step once the workflow is fully completed" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "approved")
    create(:review_step, :history_check, loan_application: application, status: "approved")
    create(:review_step, :phone_screening, loan_application: application, status: "approved")
    create(:review_step, :verification, loan_application: application, status: "approved")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_application_path(application)

    expect(response).to have_http_status(:ok)
    assert_select "dt", text: "Active review step"
    assert_select "dd", text: "No active step"
    assert_select "p", text: "Completed", count: 3
    assert_select "p", text: "Current stage", count: 0
  end

  it "lets a signed-in admin approve the current active review step" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "open")
    current_step = create(:review_step, :history_check, loan_application: application, status: "initialized")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch approve_loan_application_review_step_path(application, current_step)

    expect(response).to redirect_to(loan_application_path(application))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Review step approved successfully."
    assert_select "dd", text: "Phone screening"
    assert_select "span", text: "In Progress"
  end

  it "lets a signed-in admin mark the current active review step as waiting for details" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "open")
    current_step = create(:review_step, :history_check, loan_application: application, status: "initialized")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch request_details_loan_application_review_step_path(application, current_step)

    expect(response).to redirect_to(loan_application_path(application))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Review step marked as waiting for details."
    assert_select "p", text: /waiting for details before review can continue/i
    assert_select "dd", text: "History check"
  end

  it "blocks signed-in admins from mutating a non-current review step" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "in progress")
    create(:review_step, :history_check, loan_application: application, status: "initialized")
    non_current_step = create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch approve_loan_application_review_step_path(application, non_current_step)

    expect(response).to redirect_to(loan_application_path(application))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Only the current active review step can be updated."
    expect(non_current_step.reload.status).to eq("initialized")
  end

  it "blocks review-step mutations after a final application decision and hides progression controls" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "approved")
    current_step = create(:review_step, :history_check, loan_application: application, status: "initialized")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch approve_loan_application_review_step_path(application, current_step)

    expect(response).to redirect_to(loan_application_path(application))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Review steps can no longer be updated after a final decision."
    assert_select "p", text: "Review steps are locked because this application has already crossed a final decision boundary."
    assert_select "form.button_to", count: 0
    expect(current_step.reload.status).to eq("initialized")
  end

  it "saves editable pre-decision details for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "open")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch loan_application_path(application), params: {
      loan_application: {
        requested_amount: "45000",
        requested_tenure_in_months: "10",
        requested_repayment_frequency: "bi-weekly",
        proposed_interest_mode: "rate",
        request_notes: "Prefers a shorter repayment cycle."
      }
    }

    expect(response).to redirect_to(loan_application_path(application))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Application details saved successfully."
    assert_select "dd", text: "45000.00"
    assert_select "dd", text: "10 months"
    assert_select "dd", text: "Bi-Weekly"
    assert_select "dd", text: "Interest rate"
    assert_select "dd", text: "Prefers a shorter repayment cycle."
  end

  it "keeps invalid pre-decision updates on the application workspace with actionable feedback" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "open")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch loan_application_path(application), params: {
      loan_application: {
        requested_amount: "",
        requested_tenure_in_months: "",
        requested_repayment_frequency: "daily",
        proposed_interest_mode: ""
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    assert_select "h1", text: "APP-0101"
    assert_select "h2", text: "Please correct the highlighted application details."
    assert_select "p", text: "Requested amount can't be blank"
    assert_select "p", text: "Requested tenure in months can't be blank"
    assert_select "p", text: "Requested repayment frequency is not included in the list"
    assert_select "p", text: "Proposed interest mode can't be blank"
  end

  it "blocks updates after a final decision and explains the lifecycle boundary" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, :with_details, application_number: "APP-0101", status: "approved")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch loan_application_path(application), params: {
      loan_application: {
        requested_amount: "99999",
        requested_tenure_in_months: "2",
        requested_repayment_frequency: "weekly",
        proposed_interest_mode: "total_interest_amount"
      }
    }

    expect(response).to redirect_to(loan_application_path(application))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "These request details can no longer be edited after a final decision."
    assert_select "dd", text: "25000.00"
    assert_select "input[type='submit'][value='Save application details']", count: 0
  end
end
