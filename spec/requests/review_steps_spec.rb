require "rails_helper"

RSpec.describe "ReviewSteps", type: :request do
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

  describe "PATCH /loan_applications/:loan_application_id/review_steps/:id/reject" do
    it "redirects unauthenticated visitors to the sign-in page" do
      application = create(:loan_application, status: "open")
      step = create(:review_step, :history_check, loan_application: application, status: "initialized")

      patch reject_loan_application_review_step_path(application, step),
            params: { rejection_note: "Bad credit history" }

      expect(response).to redirect_to(new_session_path)
    end

    it "rejects the current active review step and marks the application as rejected" do
      user = create(:user, email_address: "admin@example.com")
      application = create(:loan_application, application_number: "APP-R01", status: "open")
      current_step = create(:review_step, :history_check, loan_application: application, status: "initialized")
      create(:review_step, :phone_screening, loan_application: application, status: "initialized")
      create(:review_step, :request_details, loan_application: application, status: "initialized")
      create(:review_step, :verification, loan_application: application, status: "initialized")

      sign_in_as(user)
      patch reject_loan_application_review_step_path(application, current_step),
            params: { rejection_note: "Borrower has outstanding defaults." }

      expect(response).to redirect_to(loan_application_path(application))

      follow_redirect!

      expect(response).to have_http_status(:ok)
      assert_select "p", text: "Review step rejected. Application has been rejected."
      expect(current_step.reload.status).to eq("rejected")
      expect(current_step.rejection_note).to eq("Borrower has outstanding defaults.")
      expect(application.reload.status).to eq("rejected")
      expect(application.decision_notes).to eq("Borrower has outstanding defaults.")
    end

    it "blocks rejection when the rejection note is blank" do
      user = create(:user, email_address: "admin@example.com")
      application = create(:loan_application, application_number: "APP-R02", status: "open")
      current_step = create(:review_step, :history_check, loan_application: application, status: "initialized")
      create(:review_step, :phone_screening, loan_application: application, status: "initialized")
      create(:review_step, :request_details, loan_application: application, status: "initialized")
      create(:review_step, :verification, loan_application: application, status: "initialized")

      sign_in_as(user)
      patch reject_loan_application_review_step_path(application, current_step),
            params: { rejection_note: "" }

      expect(response).to redirect_to(loan_application_path(application))

      follow_redirect!

      expect(response).to have_http_status(:ok)
      assert_select "p", text: "A rejection note is required when rejecting a review step."
      expect(current_step.reload.status).to eq("initialized")
      expect(application.reload.status).to eq("open")
    end

    it "blocks rejection of a non-current review step" do
      user = create(:user, email_address: "admin@example.com")
      application = create(:loan_application, application_number: "APP-R03", status: "in progress")
      create(:review_step, :history_check, loan_application: application, status: "initialized")
      non_current_step = create(:review_step, :phone_screening, loan_application: application, status: "initialized")
      create(:review_step, :request_details, loan_application: application, status: "initialized")
      create(:review_step, :verification, loan_application: application, status: "initialized")

      sign_in_as(user)
      patch reject_loan_application_review_step_path(application, non_current_step),
            params: { rejection_note: "Should not apply" }

      expect(response).to redirect_to(loan_application_path(application))

      follow_redirect!

      expect(response).to have_http_status(:ok)
      assert_select "p", text: "Only the current active review step can be updated."
      expect(non_current_step.reload.status).to eq("initialized")
    end

    it "blocks rejection after a final application decision" do
      user = create(:user, email_address: "admin@example.com")
      application = create(:loan_application, application_number: "APP-R04", status: "approved")
      step = create(:review_step, :history_check, loan_application: application, status: "initialized")
      create(:review_step, :phone_screening, loan_application: application, status: "initialized")
      create(:review_step, :request_details, loan_application: application, status: "initialized")
      create(:review_step, :verification, loan_application: application, status: "initialized")

      sign_in_as(user)
      patch reject_loan_application_review_step_path(application, step),
            params: { rejection_note: "Late attempt" }

      expect(response).to redirect_to(loan_application_path(application))

      follow_redirect!

      expect(response).to have_http_status(:ok)
      assert_select "p", text: "Review steps can no longer be updated after a final decision."
      expect(step.reload.status).to eq("initialized")
    end

    it "preserves the from=applications context through the redirect" do
      user = create(:user, email_address: "admin@example.com")
      application = create(:loan_application, application_number: "APP-R05", status: "open")
      current_step = create(:review_step, :history_check, loan_application: application, status: "initialized")
      create(:review_step, :phone_screening, loan_application: application, status: "initialized")
      create(:review_step, :request_details, loan_application: application, status: "initialized")
      create(:review_step, :verification, loan_application: application, status: "initialized")

      sign_in_as(user)
      patch reject_loan_application_review_step_path(application, current_step),
            params: { rejection_note: "Rejected with context", from: "applications" }

      expect(response).to redirect_to(loan_application_path(application, from: "applications"))
    end

    it "normalizes whitespace in the rejection note" do
      user = create(:user, email_address: "admin@example.com")
      application = create(:loan_application, application_number: "APP-R06", status: "open")
      current_step = create(:review_step, :history_check, loan_application: application, status: "initialized")
      create(:review_step, :phone_screening, loan_application: application, status: "initialized")
      create(:review_step, :request_details, loan_application: application, status: "initialized")
      create(:review_step, :verification, loan_application: application, status: "initialized")

      sign_in_as(user)
      patch reject_loan_application_review_step_path(application, current_step),
            params: { rejection_note: "  Multiple   defaults   found.  " }

      expect(response).to redirect_to(loan_application_path(application))
      expect(current_step.reload.rejection_note).to eq("Multiple defaults found.")
      expect(application.reload.decision_notes).to eq("Multiple defaults found.")
    end
  end
end
