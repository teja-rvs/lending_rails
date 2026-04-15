require "rails_helper"

RSpec.describe Loans::UpdateDetails do
  describe ".call" do
    let(:rate_attributes) do
      {
        principal_amount: 45_000,
        tenure_in_months: 10,
        repayment_frequency: "bi-weekly",
        interest_mode: "rate",
        interest_rate: "12.5000",
        total_interest_amount: nil,
        notes: "Prefers a shorter repayment cycle."
      }
    end

    it "updates loan details while the loan is still editable" do
      loan = create(:loan, :created)

      result = described_class.call(loan:, attributes: rate_attributes)

      expect(result).to be_success
      expect(result).not_to be_blocked
      expect(result).not_to be_locked
      expect(result.loan.reload.principal_amount.cents).to eq(4_500_000)
      expect(result.loan.tenure_in_months).to eq(10)
      expect(result.loan.repayment_frequency).to eq("bi-weekly")
      expect(result.loan.interest_mode).to eq("rate")
      expect(result.loan.interest_rate).to eq(BigDecimal("12.5000"))
      expect(result.loan.notes).to eq("Prefers a shorter repayment cycle.")
      expect(result.loan.versions.order(:created_at).pluck(:event).last).to eq("update")
    end

    it "updates a loan in documentation_in_progress" do
      loan = create(:loan, :documentation_in_progress)

      result = described_class.call(
        loan:,
        attributes: rate_attributes.merge(interest_rate: nil, interest_mode: "total_interest_amount", total_interest_amount: 8_000)
      )

      expect(result).to be_success
      expect(result.loan.reload.interest_mode).to eq("total_interest_amount")
      expect(result.loan.total_interest_amount.cents).to eq(800_000)
    end

    it "clears a previously saved interest rate when the form switches to total interest mode" do
      loan = create(:loan, :documentation_in_progress, :with_details)

      result = described_class.call(
        loan:,
        attributes: {
          principal_amount: 45_000,
          tenure_in_months: 12,
          repayment_frequency: "monthly",
          interest_mode: "total_interest_amount",
          total_interest_amount: 8_000,
          notes: "Switched to a fixed total amount."
        }
      )

      expect(result).to be_success
      expect(result.loan.reload.interest_mode).to eq("total_interest_amount")
      expect(result.loan.interest_rate).to be_nil
      expect(result.loan.total_interest_amount.cents).to eq(800_000)
    end

    it "clears a previously saved total interest amount when the form switches to rate mode" do
      loan = create(:loan, :documentation_in_progress, :with_total_interest_details)

      result = described_class.call(
        loan:,
        attributes: {
          principal_amount: 45_000,
          tenure_in_months: 12,
          repayment_frequency: "monthly",
          interest_mode: "rate",
          interest_rate: "12.5000",
          notes: "Switched back to a percentage rate."
        }
      )

      expect(result).to be_success
      expect(result.loan.reload.interest_mode).to eq("rate")
      expect(result.loan.total_interest_amount).to be_nil
      expect(result.loan.interest_rate).to eq(BigDecimal("12.5000"))
    end

    it "returns validation errors when the submitted details are incomplete" do
      loan = create(:loan, :created)

      result = described_class.call(
        loan:,
        attributes: rate_attributes.merge(principal_amount: nil, interest_rate: nil)
      )

      expect(result).not_to be_success
      expect(result).not_to be_blocked
      expect(result).not_to be_locked
      expect(result.loan.errors[:principal_amount]).to include("can't be blank")
      expect(result.loan.errors[:interest_rate]).to include("can't be blank")
    end

    it "blocks updates after the loan has crossed the disbursement boundary" do
      loan = create(:loan, :active, :with_details)

      result = described_class.call(loan:, attributes: rate_attributes)

      expect(result).not_to be_success
      expect(result).to be_blocked
      expect(result).to be_locked
      expect(result.loan.reload.principal_amount.cents).to eq(4_500_000)
      expect(result.loan.errors[:base]).to include("These loan details can no longer be edited after disbursement.")
    end
  end
end
