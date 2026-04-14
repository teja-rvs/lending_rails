require "rails_helper"

RSpec.describe LoanApplications::Reject do
  describe ".call" do
    it "rejects an open application and stores normalized decision notes" do
      loan_application = create(:loan_application, status: "open")

      result = described_class.call(
        loan_application:,
        decision_notes: "  Missing   supporting documents.  "
      )

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.loan_application.reload.status).to eq("rejected")
      expect(result.loan_application.decision_notes).to eq("Missing supporting documents.")
      expect(result.loan_application.versions.order(:created_at).pluck(:event).last).to eq("update")
    end

    it "rejects an in-progress application without requiring decision notes" do
      loan_application = create(:loan_application, status: "in progress")

      result = described_class.call(loan_application:)

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.loan_application.reload.status).to eq("rejected")
      expect(result.loan_application.decision_notes).to be_nil
    end

    it "blocks rejection when the application is already in a final state" do
      loan_application = create(:loan_application, status: "approved")

      result = described_class.call(loan_application:, decision_notes: "Too late")

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This application has already reached a final decision.")
      expect(loan_application.reload.status).to eq("approved")
    end
  end
end
