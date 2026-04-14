require "rails_helper"

RSpec.describe Loans::CreateFromApplication do
  describe ".call" do
    it "creates a created loan from an approved application" do
      borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
      create(:loan, loan_number: "LOAN-0003")
      loan_application = create(:loan_application, :approved, borrower:)

      borrower.update!(full_name: "Asha R. Patel", phone_number: "+91 98765 40000")

      result = described_class.call(loan_application:)

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result.loan).to have_attributes(
        borrower:,
        loan_application:,
        loan_number: "LOAN-0004",
        status: "created",
        borrower_full_name_snapshot: "Asha R. Patel",
        borrower_phone_number_snapshot: borrower.phone_number_normalized
      )
      expect(loan_application.reload.loan).to eq(result.loan)
    end

    it "blocks when the application is not approved" do
      loan_application = create(:loan_application, :in_progress)

      result = described_class.call(loan_application:)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("Application is not approved.")
      expect(loan_application.reload.loan).to be_nil
    end

    it "blocks when the application already has a loan" do
      loan_application = create(:loan_application, :approved)
      create(:loan, loan_application:, borrower: loan_application.borrower)

      result = described_class.call(loan_application:)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result.error).to eq("A loan already exists for this application.")
    end
  end
end
