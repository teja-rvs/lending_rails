require "rails_helper"

RSpec.describe Loans::EvaluateDisbursementReadiness do
  describe ".call" do
    def readiness_item(result, key)
      result.items.find { |item| item.key == key }
    end

    it "blocks a created loan until documentation is complete even when financial details are present" do
      loan = create(:loan, :created, :with_details)

      result = described_class.call(loan:)

      expect(result).not_to be_ready_for_disbursement_action
      expect(result.blocked_summary).to include("loan has not reached Ready for Disbursement")

      lifecycle_item = readiness_item(result, :lifecycle_ready_for_disbursement)
      financial_item = readiness_item(result, :financial_details_complete)

      expect(lifecycle_item).to have_attributes(
        key: :lifecycle_ready_for_disbursement,
        label: "Loan has reached ready for disbursement",
        detail: "The loan is still in the created stage, so documentation has not been completed yet.",
        next_step: "Begin documentation, complete any remaining loan details, and finish documentation before attempting disbursement."
      )
      expect(lifecycle_item).not_to be_met

      expect(financial_item).to have_attributes(
        key: :financial_details_complete,
        label: "Required financial details are complete",
        detail: "Principal, processing fee, tenure, repayment frequency, and interest details satisfy the pre-disbursement validation rules.",
        next_step: "No action needed."
      )
      expect(financial_item).to be_met
    end

    it "surfaces the missing financial fields for a created loan with incomplete details" do
      loan = create(:loan, :created)

      result = described_class.call(loan:)

      expect(result).not_to be_ready_for_disbursement_action

      financial_item = readiness_item(result, :financial_details_complete)

      expect(financial_item).not_to be_met
      expect(financial_item.detail).to eq(
        "Principal amount can't be blank, Tenure in months can't be blank, Repayment frequency can't be blank, and Interest mode can't be blank."
      )
      expect(financial_item.next_step).to eq(
        "Update the pre-disbursement loan details so every required financial field is complete and internally consistent."
      )
      expect(result.blocked_summary).to include("Required financial details are incomplete")
    end

    it "keeps documentation_in_progress loans blocked until the documentation stage is finished" do
      loan = create(:loan, :documentation_in_progress, :with_details)

      result = described_class.call(loan:)

      expect(result).not_to be_ready_for_disbursement_action

      lifecycle_item = readiness_item(result, :lifecycle_ready_for_disbursement)

      expect(lifecycle_item).not_to be_met
      expect(lifecycle_item.detail).to eq(
        "Documentation is still in progress, so the loan cannot move to disbursement yet."
      )
      expect(lifecycle_item.next_step).to eq(
        "Finish any remaining documentation work, then complete documentation to move the loan into Ready for Disbursement."
      )
    end

    it "returns a ready result for ready_for_disbursement loans with complete details" do
      loan = create(:loan, :ready_for_disbursement, :with_details)

      result = described_class.call(loan:)

      expect(result).to be_ready_for_disbursement_action
      expect(result.blocked_summary).to be_nil
      expect(result.items.map(&:key)).to eq(
        %i[lifecycle_ready_for_disbursement financial_details_complete]
      )
      expect(result.items).to all(be_met)
    end

    it "blocks ready_for_disbursement loans when required financial details are still missing" do
      loan = create(:loan, :ready_for_disbursement)

      result = described_class.call(loan:)

      expect(result).not_to be_ready_for_disbursement_action

      lifecycle_item = readiness_item(result, :lifecycle_ready_for_disbursement)
      financial_item = readiness_item(result, :financial_details_complete)

      expect(lifecycle_item).to be_met
      expect(financial_item).not_to be_met
      expect(result.blocked_summary).to include("Required financial details are incomplete")
      expect(result.blocked_summary).to include("Complete the missing pre-disbursement loan details before attempting disbursement.")
    end

    it "returns a ready result for ready_for_disbursement loans that use total interest amount details" do
      loan = create(:loan, :ready_for_disbursement, :with_total_interest_details)

      result = described_class.call(loan:)

      expect(result).to be_ready_for_disbursement_action
      expect(result.blocked_summary).to be_nil
      expect(result.items).to all(be_met)
    end

    it "surfaces missing total interest amount details for fixed-interest loans" do
      loan = create(
        :loan,
        :ready_for_disbursement,
        principal_amount: 45_000,
        tenure_in_months: 12,
        repayment_frequency: "monthly",
        interest_mode: "total_interest_amount",
        total_interest_amount: nil
      )

      result = described_class.call(loan:)

      expect(result).not_to be_ready_for_disbursement_action

      financial_item = readiness_item(result, :financial_details_complete)

      expect(financial_item).not_to be_met
      expect(financial_item.detail).to eq("Total interest amount can't be blank.")
      expect(result.blocked_summary).to include("Required financial details are incomplete")
      expect(result.blocked_summary).to include("Complete the missing pre-disbursement loan details before attempting disbursement.")
    end
  end
end
