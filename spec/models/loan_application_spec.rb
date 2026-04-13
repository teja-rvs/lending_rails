require "rails_helper"

RSpec.describe LoanApplication, type: :model do
  describe "application number generation" do
    it "assigns the next APP number when one is not provided" do
      create(:loan_application, application_number: "APP-0007")

      loan_application = described_class.create!(borrower: create(:borrower), status: "open")

      expect(loan_application.application_number).to eq("APP-0008")
    end

    it "preserves an explicit application number" do
      loan_application = described_class.create!(
        borrower: create(:borrower),
        application_number: "APP-0420",
        status: "open"
      )

      expect(loan_application.application_number).to eq("APP-0420")
    end
  end

  describe "pre-decision detail validation" do
    it "requires the MVP pre-decision fields during details updates" do
      loan_application = build(:loan_application)

      expect(loan_application.valid?(:details_update)).to be(false)
      expect(loan_application.errors[:requested_amount]).to include("can't be blank")
      expect(loan_application.errors[:requested_tenure_in_months]).to include("can't be blank")
      expect(loan_application.errors[:requested_repayment_frequency]).to include("can't be blank")
      expect(loan_application.errors[:proposed_interest_mode]).to include("can't be blank")
    end

    it "requires a positive requested amount" do
      loan_application = build(
        :loan_application,
        requested_amount: 0,
        requested_tenure_in_months: 12,
        requested_repayment_frequency: "monthly",
        proposed_interest_mode: "rate"
      )

      expect(loan_application.valid?(:details_update)).to be(false)
      expect(loan_application.errors[:requested_amount]).to include("must be greater than 0")
    end

    it "accepts only supported repayment frequencies" do
      loan_application = build(
        :loan_application,
        requested_amount: 25_000,
        requested_tenure_in_months: 12,
        requested_repayment_frequency: "daily",
        proposed_interest_mode: "rate"
      )

      expect(loan_application.valid?(:details_update)).to be(false)
      expect(loan_application.errors[:requested_repayment_frequency]).to include("is not included in the list")
    end

    it "accepts only supported proposed interest modes" do
      loan_application = build(
        :loan_application,
        requested_amount: 25_000,
        requested_tenure_in_months: 12,
        requested_repayment_frequency: "monthly",
        proposed_interest_mode: "flat"
      )

      expect(loan_application.valid?(:details_update)).to be(false)
      expect(loan_application.errors[:proposed_interest_mode]).to include("is not included in the list")
    end
  end

  describe "#editable_pre_decision_details?" do
    it "returns true before a final decision" do
      expect(build(:loan_application, status: "open")).to be_editable_pre_decision_details
      expect(build(:loan_application, status: "in progress")).to be_editable_pre_decision_details
    end

    it "returns false after a final decision" do
      expect(build(:loan_application, status: "approved")).not_to be_editable_pre_decision_details
      expect(build(:loan_application, status: "rejected")).not_to be_editable_pre_decision_details
      expect(build(:loan_application, status: "cancelled")).not_to be_editable_pre_decision_details
    end
  end

  describe "#active_review_step" do
    it "returns the first ordered review step that is still in progress" do
      loan_application = create(:loan_application)
      create(
        :review_step,
        loan_application:,
        step_key: "history_check",
        position: 1,
        status: "approved"
      )
      active_step = create(
        :review_step,
        loan_application:,
        step_key: "phone_screening",
        position: 2,
        status: "initialized"
      )
      create(
        :review_step,
        loan_application:,
        step_key: "verification",
        position: 3,
        status: "initialized"
      )

      expect(loan_application.active_review_step).to eq(active_step)
    end
  end

  describe "audit history" do
    it "tracks create and update events with paper trail" do
      loan_application = create(:loan_application)

      expect(loan_application.versions.pluck(:event)).to include("create")

      loan_application.update!(
        requested_amount: 15_000,
        requested_tenure_in_months: 10,
        requested_repayment_frequency: "monthly",
        proposed_interest_mode: "rate"
      )

      expect(loan_application.versions.order(:created_at).pluck(:event).last).to eq("update")
    end
  end
end
