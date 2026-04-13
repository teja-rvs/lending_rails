require "rails_helper"

RSpec.describe LoanApplications::UpdateDetails do
  describe ".call" do
    let(:attributes) do
      {
        requested_amount: 45_000,
        requested_tenure_in_months: 10,
        requested_repayment_frequency: "bi-weekly",
        proposed_interest_mode: "rate",
        request_notes: "Prefers a shorter repayment cycle."
      }
    end

    it "updates pre-decision details while the application is editable" do
      loan_application = create(:loan_application)

      result = described_class.call(loan_application:, attributes:)

      expect(result).to be_success
      expect(result).not_to be_locked
      expect(result.loan_application.reload.requested_amount.cents).to eq(4_500_000)
      expect(result.loan_application.requested_tenure_in_months).to eq(10)
      expect(result.loan_application.requested_repayment_frequency).to eq("bi-weekly")
      expect(result.loan_application.proposed_interest_mode).to eq("rate")
      expect(result.loan_application.request_notes).to eq("Prefers a shorter repayment cycle.")
      expect(result.loan_application.versions.order(:created_at).pluck(:event).last).to eq("update")
    end

    it "returns validation errors when the submitted details are incomplete" do
      loan_application = create(:loan_application)

      result = described_class.call(
        loan_application:,
        attributes: attributes.merge(requested_amount: nil, proposed_interest_mode: nil)
      )

      expect(result).not_to be_success
      expect(result).not_to be_locked
      expect(result.loan_application.errors[:requested_amount]).to include("can't be blank")
      expect(result.loan_application.errors[:proposed_interest_mode]).to include("can't be blank")
    end

    it "blocks updates after a final decision" do
      loan_application = create(:loan_application, status: "approved", requested_amount: 20_000)

      result = described_class.call(loan_application:, attributes:)

      expect(result).not_to be_success
      expect(result).to be_locked
      expect(result.loan_application.reload.requested_amount.cents).to eq(2_000_000)
      expect(result.loan_application.errors[:base]).to include("These request details can no longer be edited after a final decision.")
    end
  end
end
