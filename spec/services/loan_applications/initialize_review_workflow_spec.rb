require "rails_helper"

RSpec.describe LoanApplications::InitializeReviewWorkflow do
  describe ".call" do
    it "creates the fixed workflow in canonical order" do
      loan_application = create(:loan_application)

      described_class.call(loan_application:)

      expect(loan_application.review_steps.pluck(:step_key, :position, :status)).to eq(
        [
          [ "history_check", 1, "initialized" ],
          [ "phone_screening", 2, "initialized" ],
          [ "request_details", 3, "initialized" ],
          [ "verification", 4, "initialized" ]
        ]
      )
    end

    it "backfills missing workflow steps only once for an existing application" do
      loan_application = create(:loan_application)

      expect {
        described_class.call(loan_application:)
        described_class.call(loan_application:)
      }.to change(ReviewStep, :count).by(4)
    end
  end
end
