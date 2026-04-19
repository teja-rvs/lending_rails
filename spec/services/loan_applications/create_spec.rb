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
      expect(result.loan_application.review_steps.pluck(:step_key, :position, :status)).to eq(
        [
          [ "history_check", 1, "initialized" ],
          [ "phone_screening", 2, "initialized" ],
          [ "verification", 3, "initialized" ]
        ]
      )
    end

    it "captures the borrower's name and phone at creation time, unaffected by later borrower changes" do
      borrower = create(:borrower, full_name: "Asha Patel", phone_number: "+91 98765 43210")

      result = described_class.call(borrower:)

      expect(result).to be_success
      expect(result.loan_application.borrower_full_name_snapshot).to eq("Asha Patel")
      expect(result.loan_application.borrower_phone_number_snapshot).to eq("+919876543210")

      borrower.update!(full_name: "Asha R. Patel", phone_number: "+91 98765 99999")

      expect(result.loan_application.reload.borrower_full_name_snapshot).to eq("Asha Patel")
      expect(result.loan_application.borrower_phone_number_snapshot).to eq("+919876543210")
    end

    it "uses serialized allocation to prevent application number collisions" do
      borrower1 = create(:borrower, phone_number: "+91 98765 00001")
      borrower2 = create(:borrower, phone_number: "+91 98765 00002")

      result1 = described_class.call(borrower: borrower1)
      result2 = described_class.call(borrower: borrower2)

      expect(result1).to be_success
      expect(result2).to be_success
      expect(result1.loan_application.application_number).not_to eq(result2.loan_application.application_number)
      expect(result1.loan_application.application_number).to match(/\AAPP-\d{4}\z/)
      expect(result2.loan_application.application_number).to match(/\AAPP-\d{4}\z/)
    end

    it "blocks creation when the borrower has a blocking application" do
      borrower = create(:borrower)
      create(:loan_application, borrower:, status: "open")

      expect {
        @result = described_class.call(borrower:)
      }.not_to change(ReviewStep, :count)

      result = @result

      expect(result).not_to be_success
      expect(result.eligibility).to be_blocked
      expect(result.loan_application).not_to be_persisted
      expect(result.loan_application.errors[:base]).to include("A new application cannot be started for this borrower right now.")
    end

    it "blocks creation when the borrower has a blocking loan" do
      borrower = create(:borrower)
      create(:loan, borrower:, status: "active")

      expect {
        @result = described_class.call(borrower:)
      }.not_to change(ReviewStep, :count)

      result = @result

      expect(result).not_to be_success
      expect(result.eligibility).to be_blocked
      expect(result.loan_application).not_to be_persisted
      expect(result.loan_application.errors[:base]).to include("A new application cannot be started for this borrower right now.")
    end

    it "rolls back the application when workflow initialization fails" do
      borrower = create(:borrower)
      review_step = build(:review_step)

      allow(LoanApplications::InitializeReviewWorkflow).to receive(:call)
        .and_raise(ActiveRecord::RecordInvalid.new(review_step))

      expect {
        described_class.call(borrower:)
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(LoanApplication.count).to eq(0)
      expect(ReviewStep.count).to eq(0)
    end
  end
end
