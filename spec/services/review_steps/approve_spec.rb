require "rails_helper"

RSpec.describe ReviewSteps::Approve do
  describe ".call" do
    it "approves the current active step and advances the workflow" do
      loan_application = create(:loan_application, status: "open")
      current_step = create(:review_step, :history_check, loan_application:, status: "initialized")
      next_step = create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id)

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.review_step.reload.status).to eq("approved")
      expect(result.loan_application.reload.status).to eq("in progress")
      expect(result.loan_application.active_review_step).to eq(next_step)
    end

    it "allows the waiting current step to move forward once details are available" do
      loan_application = create(:loan_application, status: "in progress")
      current_step = create(:review_step, :history_check, loan_application:, status: "waiting for details")
      next_step = create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id)

      expect(result).to be_success
      expect(current_step.reload.status).to eq("approved")
      expect(loan_application.reload.active_review_step).to eq(next_step)
    end

    it "blocks out-of-order progression with clear feedback" do
      loan_application = create(:loan_application, status: "in progress")
      create(:review_step, :history_check, loan_application:, status: "initialized")
      non_current_step = create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: non_current_step.id)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("Only the current active review step can be updated.")
      expect(non_current_step.reload.status).to eq("initialized")
    end

    it "locks the loan application during workflow mutation" do
      loan_application = create(:loan_application, status: "open")
      current_step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      expect(loan_application).to receive(:with_lock).and_call_original

      described_class.call(loan_application:, review_step_id: current_step.id)
    end

    it "blocks review-step approval after a final application decision" do
      loan_application = create(:loan_application, status: "approved")
      current_step = create(:review_step, :history_check, loan_application:, status: "initialized")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      result = described_class.call(loan_application:, review_step_id: current_step.id)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("Review steps can no longer be updated after a final decision.")
      expect(current_step.reload.status).to eq("initialized")
    end
  end
end
