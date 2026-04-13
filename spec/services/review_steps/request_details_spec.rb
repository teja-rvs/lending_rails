require "rails_helper"

RSpec.describe ReviewSteps::RequestDetails do
  describe ".call" do
    it "marks the current active step as waiting for details and keeps it active" do
      loan_application = create(:loan_application, status: "open")
      current_step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id)

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(current_step.reload.status).to eq("waiting for details")
      expect(loan_application.reload.status).to eq("in progress")
      expect(loan_application.active_review_step).to eq(current_step)
    end

    it "blocks non-current steps with clear feedback" do
      loan_application = create(:loan_application, status: "in progress")
      create(:review_step, :history_check, loan_application:, status: "initialized")
      non_current_step = create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: non_current_step.id)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("Only the current active review step can be updated.")
      expect(non_current_step.reload.status).to eq("initialized")
    end

    it "blocks requesting details after a final application decision" do
      loan_application = create(:loan_application, status: "cancelled")
      current_step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("Review steps can no longer be updated after a final decision.")
      expect(current_step.reload.status).to eq("initialized")
    end
  end
end
