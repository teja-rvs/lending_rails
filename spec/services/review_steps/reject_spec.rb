require "rails_helper"

RSpec.describe ReviewSteps::Reject do
  describe ".call" do
    it "rejects the current active step and auto-rejects the application" do
      loan_application = create(:loan_application, status: "open")
      current_step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id, rejection_note: "Failed history check.")

      expect(result).to be_success
      expect(current_step.reload.status).to eq("rejected")
      expect(current_step.rejection_note).to eq("Failed history check.")
      expect(loan_application.reload.status).to eq("rejected")
      expect(loan_application.decision_notes).to eq("Failed history check.")
    end

    it "blocks rejection without a note" do
      loan_application = create(:loan_application, status: "open")
      current_step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id, rejection_note: "")

      expect(result).to be_blocked
      expect(result.error).to eq("A rejection note is required when rejecting a review step.")
      expect(current_step.reload.status).to eq("initialized")
      expect(loan_application.reload.status).to eq("open")
    end

    it "blocks rejection of non-active steps" do
      loan_application = create(:loan_application, status: "in progress")
      create(:review_step, :history_check, loan_application:, status: "initialized")
      non_current = create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: non_current.id, rejection_note: "Should fail.")

      expect(result).to be_blocked
      expect(result.error).to eq("Only the current active review step can be updated.")
    end

    it "blocks rejection after a final application decision" do
      loan_application = create(:loan_application, status: "approved")
      current_step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id, rejection_note: "Too late.")

      expect(result).to be_blocked
      expect(result.error).to eq("Review steps can no longer be updated after a final decision.")
    end

    it "rejects a step that is waiting for details" do
      loan_application = create(:loan_application, status: "in progress")
      current_step = create(:review_step, :history_check, loan_application:, status: "waiting for details")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id, rejection_note: "Details insufficient.")

      expect(result).to be_success
      expect(current_step.reload.status).to eq("rejected")
      expect(loan_application.reload.status).to eq("rejected")
    end
  end
end
