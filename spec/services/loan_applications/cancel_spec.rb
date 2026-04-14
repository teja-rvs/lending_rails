require "rails_helper"

RSpec.describe LoanApplications::Cancel do
  describe ".call" do
    it "cancels an open application and stores normalized decision notes" do
      loan_application = create(:loan_application, status: "open")

      result = described_class.call(
        loan_application:,
        decision_notes: "  Borrower   withdrew the request. "
      )

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.loan_application.reload.status).to eq("cancelled")
      expect(result.loan_application.decision_notes).to eq("Borrower withdrew the request.")
      expect(result.loan_application.versions.order(:created_at).pluck(:event).last).to eq("update")
    end

    it "cancels an in-progress application without requiring decision notes" do
      loan_application = create(:loan_application, status: "in progress")

      result = described_class.call(loan_application:)

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.loan_application.reload.status).to eq("cancelled")
      expect(result.loan_application.decision_notes).to be_nil
    end

    it "blocks cancellation when the application is already in a final state" do
      loan_application = create(:loan_application, status: "rejected")

      result = described_class.call(loan_application:, decision_notes: "Too late")

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This application has already reached a final decision.")
      expect(loan_application.reload.status).to eq("rejected")
    end
  end
end
