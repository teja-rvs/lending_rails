require "rails_helper"

RSpec.describe "LoanApplications", type: :request do
  around do |example|
    original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
    ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
    example.run
  ensure
    ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123!" }
  end

  def create_completed_review_workflow(loan_application)
    create(:review_step, :history_check, loan_application:, status: "approved")
    create(:review_step, :phone_screening, loan_application:, status: "approved")
    create(:review_step, :verification, loan_application:, status: "approved")
  end

  it "redirects unauthenticated visitors away from the loan application detail page" do
    application = create(:loan_application)

    get loan_application_path(application)

    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated visitors away from the applications list" do
    get loan_applications_path

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

  it "redirects unauthenticated visitors away from application decision actions" do
    approvable_application = create(:loan_application, status: "in progress")
    create_completed_review_workflow(approvable_application)
    rejectable_application = create(:loan_application, status: "open")

    patch approve_loan_application_path(approvable_application)
    expect(response).to redirect_to(new_session_path)

    patch reject_loan_application_path(rejectable_application)
    expect(response).to redirect_to(new_session_path)

    patch cancel_loan_application_path(rejectable_application)
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

  it "renders an empty applications list state for signed-in admins" do
    user = create(:user, email_address: "admin@example.com")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_applications_path

    expect(response).to have_http_status(:ok)
    assert_select "title", text: "Applications | lending_rails"
    assert_select "h1", text: "Applications"
    assert_select "h2", text: "No applications found"
  end

  it "filters the applications list by status" do
    user = create(:user, email_address: "admin@example.com")
    matching = create(:loan_application, application_number: "APP-0101", status: "approved")
    create(:loan_application, application_number: "APP-0102", status: "open")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_applications_path, params: { status: "approved" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_application_path(matching, from: "applications")}']", text: matching.application_number
    assert_select "a", text: "APP-0102", count: 0
  end

  it "searches the applications list by borrower name" do
    user = create(:user, email_address: "admin@example.com")
    matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    matching = create(:loan_application, borrower: matching_borrower, application_number: "APP-0101", status: "open")
    other_borrower = create(:borrower, full_name: "Rahul Singh", phone_number: "91234 56789")
    create(:loan_application, borrower: other_borrower, application_number: "APP-0102", status: "open")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_applications_path, params: { q: "Asha" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_application_path(matching, from: "applications")}']", text: matching.application_number
    assert_select "td", text: "Rahul Singh", count: 0
  end

  it "searches the applications list by borrower phone number" do
    user = create(:user, email_address: "admin@example.com")
    matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    matching = create(:loan_application, borrower: matching_borrower, application_number: "APP-0103", status: "open")
    other_borrower = create(:borrower, full_name: "Rahul Singh", phone_number: "91234 56789")
    create(:loan_application, borrower: other_borrower, application_number: "APP-0104", status: "open")

    sign_in_as(user)
    get loan_applications_path, params: { q: "98765" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_application_path(matching, from: "applications")}']", text: matching.application_number
    assert_select "td", text: "Rahul Singh", count: 0
  end

  it "searches the applications list by application number" do
    user = create(:user, email_address: "admin@example.com")
    matching = create(:loan_application, application_number: "APP-0105", status: "open")
    create(:loan_application, application_number: "APP-0106", status: "open")

    sign_in_as(user)
    get loan_applications_path, params: { q: "APP-0105" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_application_path(matching, from: "applications")}']", text: matching.application_number
    assert_select "a", text: "APP-0106", count: 0
  end

  it "applies search and status filters together on the applications list" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    matching = create(:loan_application, borrower:, application_number: "APP-0107", status: "approved")
    create(:loan_application, borrower:, application_number: "APP-0108", status: "open")

    sign_in_as(user)
    get loan_applications_path, params: { q: "Asha", status: "approved" }

    expect(response).to have_http_status(:ok)
    assert_select "a[href='#{loan_application_path(matching, from: "applications")}']", text: matching.application_number
    assert_select "a", text: "APP-0108", count: 0
  end

  it "shows 'No applications match' empty state when search returns no results" do
    user = create(:user, email_address: "admin@example.com")
    create(:loan_application, application_number: "APP-0109", status: "open")

    sign_in_as(user)
    get loan_applications_path, params: { q: "nonexistent" }

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "No applications match the current filters"
    assert_select "a", text: "Clear filters"
  end

  it "preserves the status filter in the search form via hidden field" do
    user = create(:user, email_address: "admin@example.com")
    create(:loan_application, application_number: "APP-0110", status: "approved")

    sign_in_as(user)
    get loan_applications_path, params: { status: "approved" }

    expect(response).to have_http_status(:ok)
    assert_select "input[type='hidden'][name='status'][value='approved']"
  end

  it "filters the applications list by multi-status comma param" do
    user = create(:user, email_address: "admin@example.com")
    open_app = create(:loan_application, application_number: "APP-0201", status: "open")
    in_progress_app = create(:loan_application, application_number: "APP-0202", status: "in progress")
    create(:loan_application, application_number: "APP-0203", status: "approved")
    create(:loan_application, application_number: "APP-0204", status: "rejected")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_applications_path, params: { status: "open,in progress" }

    expect(response).to have_http_status(:ok)
    assert_select "a", text: open_app.application_number
    assert_select "a", text: in_progress_app.application_number
    assert_select "a", text: "APP-0203", count: 0
    assert_select "a", text: "APP-0204", count: 0
  end

  it "ignores invalid statuses in a multi-status comma param" do
    user = create(:user, email_address: "admin@example.com")
    open_app = create(:loan_application, application_number: "APP-0301", status: "open")
    create(:loan_application, application_number: "APP-0302", status: "approved")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_applications_path, params: { status: "open,bogus" }

    expect(response).to have_http_status(:ok)
    assert_select "a", text: open_app.application_number
    assert_select "a", text: "APP-0302", count: 0
  end

  it "renders filter context banner when single-status filter is applied" do
    user = create(:user, email_address: "admin@example.com")
    create(:loan_application, application_number: "APP-0601", status: "approved")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_applications_path, params: { status: "approved" }

    expect(response).to have_http_status(:ok)
    assert_select "div.bg-slate-50", text: /approved applications/i
    assert_select "a", text: "Clear filters"
  end

  it "renders filter context banner when multi-status filter is applied" do
    user = create(:user, email_address: "admin@example.com")
    create(:loan_application, application_number: "APP-0401", status: "open")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_applications_path, params: { status: "open,in progress" }

    expect(response).to have_http_status(:ok)
    assert_select "div.bg-slate-50", text: /open or in progress applications/i
    assert_select "a", text: "Clear filters"
  end

  it "renders drill-in empty state for multi-status filter with no results" do
    user = create(:user, email_address: "admin@example.com")
    create(:loan_application, application_number: "APP-0501", status: "approved")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_applications_path, params: { status: "open,in progress" }

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: /No open or in progress applications/
    assert_select "a", text: "Return to dashboard"
  end

  it "renders borrower lending context within the application workspace" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "in progress")
    prior_application = create(:loan_application, borrower:, application_number: "APP-0009", status: "approved")
    loan = create(:loan, borrower:, loan_application: prior_application, loan_number: "LOAN-0003", status: "active")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_application_path(application)

    expect(response).to have_http_status(:ok)
    assert_select "section#borrower-lending-context h2", text: "Borrower lending context"
    assert_select "section#borrower-lending-context h3", text: "Borrower has active lending work"
    assert_select "section#borrower-lending-context p", text: /1 blocking loan and 2 blocking applications linked to this borrower today\./
    assert_select "section#borrower-lending-context a[href='#{borrower_path(borrower)}']", text: "View full borrower profile"
    assert_select "section#borrower-lending-context a[href='#{loan_application_path(prior_application)}']", text: prior_application.application_number
    assert_select "section#borrower-lending-context a[href='#{loan_path(loan)}']", text: loan.loan_number
    assert_select "section#borrower-lending-context a[href='#{loan_application_path(application)}']", count: 0
  end

  it "shows an empty borrower lending context state when there is no prior history beyond the current application" do
    user = create(:user, email_address: "admin@example.com")
    borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
    application = create(:loan_application, borrower:, application_number: "APP-0101", status: "open")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    get loan_application_path(application)

    expect(response).to have_http_status(:ok)
    assert_select "section#borrower-lending-context h2", text: "Borrower lending context"
    assert_select "section#borrower-lending-context p", text: "No prior lending history for this borrower beyond the current application"
    assert_select "section#borrower-lending-context a[href='#{borrower_path(borrower)}']", text: "View full borrower profile"
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

  it "lets a signed-in admin approve an application once every review step is approved" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "in progress")
    create_completed_review_workflow(application)

    sign_in_as(user)
    expect {
      patch approve_loan_application_path(application), params: { from: "applications" }
    }.to change(Loan, :count).by(1)

    expect(response).to redirect_to(loan_application_path(application, from: "applications"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    loan = application.reload.loan

    assert_select "p", text: "Application approved. Loan #{loan.loan_number} created."
    assert_select "dd", text: "Approved"
    assert_select "h2", text: "Linked loan"
    assert_select "a[href='#{loan_path(loan)}']", text: "View loan → #{loan.loan_number}"
    expect(application.reload.status).to eq("approved")
  end

  it "blocks signed-in admins from approving an application before every review step is approved" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "in progress")
    create(:review_step, :history_check, loan_application: application, status: "approved")
    create(:review_step, :phone_screening, loan_application: application, status: "rejected")
    create(:review_step, :verification, loan_application: application, status: "approved")

    sign_in_as(user)
    patch approve_loan_application_path(application), params: { from: "applications" }

    expect(response).to redirect_to(loan_application_path(application, from: "applications"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "This application can only be approved after every review step is approved."
    expect(application.reload.status).to eq("in progress")
  end

  it "lets a signed-in admin reject an application during review" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "open")

    sign_in_as(user)
    patch reject_loan_application_path(application), params: {
      from: "applications",
      decision_notes: "  Missing   supporting documents. "
    }

    expect(response).to redirect_to(loan_application_path(application, from: "applications"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Application rejected successfully."
    expect(application.reload.status).to eq("rejected")
    expect(application.decision_notes).to eq("Missing supporting documents.")
  end

  it "blocks signed-in admins from rejecting an application after a final decision" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "approved")

    sign_in_as(user)
    patch reject_loan_application_path(application), params: { from: "applications" }

    expect(response).to redirect_to(loan_application_path(application, from: "applications"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "This application has already reached a final decision."
    expect(application.reload.status).to eq("approved")
  end

  it "lets a signed-in admin cancel an application during review" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "in progress")

    sign_in_as(user)
    patch cancel_loan_application_path(application), params: {
      from: "applications",
      decision_notes: "  Borrower   withdrew the request. "
    }

    expect(response).to redirect_to(loan_application_path(application, from: "applications"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "Application cancelled successfully."
    expect(application.reload.status).to eq("cancelled")
    expect(application.decision_notes).to eq("Borrower withdrew the request.")
  end

  it "blocks signed-in admins from cancelling an application after a final decision" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "rejected")

    sign_in_as(user)
    patch cancel_loan_application_path(application), params: { from: "applications" }

    expect(response).to redirect_to(loan_application_path(application, from: "applications"))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    assert_select "p", text: "This application has already reached a final decision."
    expect(application.reload.status).to eq("rejected")
  end

  it "preserves the applications-list context after saving application details" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "open")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch loan_application_path(application), params: {
      from: "applications",
      loan_application: {
        requested_amount: "45000",
        requested_tenure_in_months: "10",
        requested_repayment_frequency: "bi-weekly",
        proposed_interest_mode: "rate",
        request_notes: "Prefers a shorter repayment cycle."
      }
    }

    expect(response).to redirect_to(loan_application_path(application, from: "applications"))
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

  it "preserves the applications-list context after review-step progression" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0101", status: "open")
    current_step = create(:review_step, :history_check, loan_application: application, status: "initialized")
    create(:review_step, :phone_screening, loan_application: application, status: "initialized")
    create(:review_step, :verification, loan_application: application, status: "initialized")

    post session_path, params: { email_address: user.email_address, password: "password123!" }
    patch approve_loan_application_review_step_path(application, current_step), params: { from: "applications" }

    expect(response).to redirect_to(loan_application_path(application, from: "applications"))
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
    assert_select "main form.button_to", count: 0
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

  it "renders the Record history section when the loan application has PaperTrail versions" do
    user = create(:user, email_address: "admin@example.com")
    application = create(:loan_application, application_number: "APP-0701", status: "open")

    sign_in_as(user)
    get loan_application_path(application)

    expect(response).to have_http_status(:ok)
    assert_select "h2", text: "Record history"
    assert_select "ol li", minimum: 1
    assert_select "p", text: "Created"
  end
end
