require "rails_helper"

RSpec.describe ReviewSteps::Transition do
  describe "abstract contract" do
    it "cannot be instantiated and called directly — subclasses must override allowed_statuses, next_status, and success_message" do
      loan_application = create(:loan_application, status: "open")
      step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      expect {
        described_class.call(loan_application:, review_step_id: step.id)
      }.to raise_error(NotImplementedError)
    end
  end

  describe "shared guard behaviour (tested via ReviewSteps::Approve)" do
    it "acquires a pessimistic lock on the loan application" do
      loan_application = create(:loan_application, status: "open")
      step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      expect(loan_application).to receive(:with_lock).and_call_original

      ReviewSteps::Approve.call(loan_application:, review_step_id: step.id)
    end

    it "blocks mutation after a final decision (approved)" do
      loan_application = create(:loan_application, status: "approved")
      step = create(:review_step, :history_check, loan_application:, status: "initialized")

      result = ReviewSteps::Approve.call(loan_application:, review_step_id: step.id)

      expect(result).to be_blocked
      expect(result.error).to eq("Review steps can no longer be updated after a final decision.")
    end

    it "blocks mutation after a final decision (rejected)" do
      loan_application = create(:loan_application, status: "rejected")
      step = create(:review_step, :history_check, loan_application:, status: "initialized")

      result = ReviewSteps::Approve.call(loan_application:, review_step_id: step.id)

      expect(result).to be_blocked
      expect(result.error).to eq("Review steps can no longer be updated after a final decision.")
    end

    it "blocks mutation after a final decision (cancelled)" do
      loan_application = create(:loan_application, status: "cancelled")
      step = create(:review_step, :history_check, loan_application:, status: "initialized")

      result = ReviewSteps::Approve.call(loan_application:, review_step_id: step.id)

      expect(result).to be_blocked
      expect(result.error).to eq("Review steps can no longer be updated after a final decision.")
    end

    it "blocks when the review step does not belong to the application" do
      loan_application = create(:loan_application, status: "open")
      create(:review_step, :history_check, loan_application:, status: "initialized")

      other_app = create(:loan_application, status: "open")
      other_step = create(:review_step, :history_check, loan_application: other_app, status: "initialized")

      result = ReviewSteps::Approve.call(loan_application:, review_step_id: other_step.id)

      expect(result).to be_blocked
      expect(result.error).to eq("The selected review step is not available for this application.")
    end

    it "blocks when there is no active step to update" do
      loan_application = create(:loan_application, status: "in progress")
      step = create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "approved")
      create(:review_step, :verification, loan_application:, status: "approved")

      result = ReviewSteps::Approve.call(loan_application:, review_step_id: step.id)

      expect(result).to be_blocked
      expect(result.error).to eq("This review workflow has no active step to update.")
    end

    it "blocks when attempting to update a non-active step" do
      loan_application = create(:loan_application, status: "open")
      create(:review_step, :history_check, loan_application:, status: "initialized")
      non_current = create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = ReviewSteps::Approve.call(loan_application:, review_step_id: non_current.id)

      expect(result).to be_blocked
      expect(result.error).to eq("Only the current active review step can be updated.")
    end

    it "blocks when the active step has already been finalized" do
      loan_application = create(:loan_application, status: "in progress")
      step = create(:review_step, :history_check, loan_application:, status: "rejected")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")

      result = ReviewSteps::RequestDetails.call(loan_application:, review_step_id: step.id)

      expect(result).to be_blocked
    end

    it "promotes application status from open to in progress on first step transition" do
      loan_application = create(:loan_application, status: "open")
      step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      ReviewSteps::Approve.call(loan_application:, review_step_id: step.id)

      expect(loan_application.reload.status).to eq("in progress")
    end

    it "does not demote application status when already in progress" do
      loan_application = create(:loan_application, status: "in progress")
      step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      ReviewSteps::Approve.call(loan_application:, review_step_id: step.id)

      expect(loan_application.reload.status).to eq("in progress")
    end
  end
end
