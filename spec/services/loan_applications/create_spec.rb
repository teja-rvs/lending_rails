require "rails_helper"

RSpec.describe LoanApplications::Create do
  describe ".call" do
    it "creates an open borrower-linked application with borrower snapshots" do
      borrower = create(:borrower, full_name: "Asha Patel", phone_number: "+91 98765 43210")

      result = described_class.call(borrower:)

      expect(result).to be_success
      expect(result.loan_application).to be_persisted
      expect(result.loan_application.status).to eq("open")
      expect(result.loan_application.application_number).to match(/\AAPP-\d{4}\z/)
      expect(result.loan_application.borrower_full_name_snapshot).to eq("Asha Patel")
      expect(result.loan_application.borrower_phone_number_snapshot).to eq("+919876543210")
    end

    it "retries when a generated application number collides" do
      borrower = create(:borrower)
      collided_record = build(
        :loan_application,
        borrower:,
        application_number: "APP-0002"
      )
      collided_record.errors.add(:application_number, :taken)
      attempts = 0

      allow(LoanApplication).to receive(:create!) do |**attributes|
        attempts += 1
        raise ActiveRecord::RecordInvalid.new(collided_record) if attempts == 1

        described_class = LoanApplication
        described_class.new(attributes).tap(&:save!)
      end

      result = described_class.call(borrower:)

      expect(result).to be_success
      expect(result.loan_application).to be_persisted
      expect(result.loan_application.application_number).to match(/\AAPP-\d{4}\z/)
      expect(attempts).to eq(2)
    end

    it "blocks creation when the borrower has a blocking application" do
      borrower = create(:borrower)
      create(:loan_application, borrower:, status: "open")

      result = described_class.call(borrower:)

      expect(result).not_to be_success
      expect(result.eligibility).to be_blocked
      expect(result.loan_application).not_to be_persisted
      expect(result.loan_application.errors[:base]).to include("A new application cannot be started for this borrower right now.")
    end

    it "blocks creation when the borrower has a blocking loan" do
      borrower = create(:borrower)
      create(:loan, borrower:, status: "active")

      result = described_class.call(borrower:)

      expect(result).not_to be_success
      expect(result.eligibility).to be_blocked
      expect(result.loan_application).not_to be_persisted
      expect(result.loan_application.errors[:base]).to include("A new application cannot be started for this borrower right now.")
    end
  end
end
