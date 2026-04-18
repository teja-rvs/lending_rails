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

      result = nil

      expect {
        result = described_class.call(loan_application:)
      }.to change(Loan, :count).by(1)

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.loan_application.reload.status).to eq("approved")
      expect(result.loan).to have_attributes(
        borrower: loan_application.borrower,
        loan_application:,
        status: "created",
        borrower_full_name_snapshot: loan_application.borrower.full_name,
        borrower_phone_number_snapshot: loan_application.borrower.phone_number_normalized
      )
      expect(result.loan_application.versions.order(:created_at).pluck(:event).last).to eq("update")
    end

    it "blocks approval when not every review step is approved" do
      loan_application = create(:loan_application, status: "in progress")
      create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "rejected")
      create(:review_step, :verification, loan_application:, status: "approved")

      result = nil

      expect {
        result = described_class.call(loan_application:)
      }.not_to change(Loan, :count)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This application can only be approved after every review step is approved.")
      expect(loan_application.reload.status).to eq("in progress")
    end

    it "blocks approval when the application is already in a final state" do
      loan_application = create(:loan_application, status: "rejected")
      create_approved_workflow(loan_application)

      result = nil

      expect {
        result = described_class.call(loan_application:)
      }.not_to change(Loan, :count)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This application has already reached a final decision.")
      expect(loan_application.reload.status).to eq("rejected")
    end

    it "blocks approval when the application is still open" do
      loan_application = create(:loan_application, status: "open")
      create_approved_workflow(loan_application)

      result = nil

      expect {
        result = described_class.call(loan_application:)
      }.not_to change(Loan, :count)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("This application can only be approved after review has started.")
      expect(loan_application.reload.status).to eq("open")
    end

    it "blocks approval when the application already has a loan" do
      loan_application = create(:loan_application, status: "in progress")
      create_approved_workflow(loan_application)
      create(:loan, loan_application:, borrower: loan_application.borrower)

      result = nil

      expect {
        result = described_class.call(loan_application:)
      }.not_to change(Loan, :count)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("A loan already exists for this application.")
    end
  end
end
