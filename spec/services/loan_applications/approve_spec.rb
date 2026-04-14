require "rails_helper"

RSpec.describe LoanApplications::Approve do
  describe ".call" do
    def create_approved_workflow(loan_application)
      create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "approved")
      create(:review_step, :verification, loan_application:, status: "approved")
    end

    it "approves an in-progress application once every review step is approved" do
      loan_application = create(:loan_application, status: "in progress")
      create_approved_workflow(loan_application)

      result = described_class.call(loan_application:)

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.loan_application.reload.status).to eq("approved")
      expect(result.loan_application.versions.order(:created_at).pluck(:event).last).to eq("update")
    end

    it "blocks approval when not every review step is approved" do
      loan_application = create(:loan_application, status: "in progress")
      create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "rejected")
      create(:review_step, :verification, loan_application:, status: "approved")

      result = described_class.call(loan_application:)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This application can only be approved after every review step is approved.")
      expect(loan_application.reload.status).to eq("in progress")
    end

    it "blocks approval when the application is already in a final state" do
      loan_application = create(:loan_application, status: "rejected")
      create_approved_workflow(loan_application)

      result = described_class.call(loan_application:)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This application has already reached a final decision.")
      expect(loan_application.reload.status).to eq("rejected")
    end

    it "blocks approval when the application is still open" do
      loan_application = create(:loan_application, status: "open")
      create_approved_workflow(loan_application)

      result = described_class.call(loan_application:)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This application can only be approved after review has started.")
      expect(loan_application.reload.status).to eq("open")
    end
  end
end
