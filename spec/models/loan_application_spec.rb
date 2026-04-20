require "rails_helper"

RSpec.describe LoanApplication, type: :model do
  describe "deletion protection" do
    subject { create(:loan_application) }

    it_behaves_like "deletion protected"
  end

  describe "snapshot presence validations" do
    it "requires borrower snapshot fields" do
      loan_application = build(
        :loan_application,
        borrower_full_name_snapshot: nil,
        borrower_phone_number_snapshot: nil
      )

      expect(loan_application).not_to be_valid
      expect(loan_application.errors[:borrower_full_name_snapshot]).to include("can't be blank")
      expect(loan_application.errors[:borrower_phone_number_snapshot]).to include("can't be blank")
    end
  end

  describe "application number generation" do
    it "assigns the next APP number when one is not provided" do
      create(:loan_application, application_number: "APP-0007")

      borrower = create(:borrower)
      loan_application = described_class.create!(
        borrower: borrower,
        status: "open",
        borrower_full_name_snapshot: borrower.full_name,
        borrower_phone_number_snapshot: borrower.phone_number_normalized
      )

      expect(loan_application.application_number).to eq("APP-0008")
    end

    it "preserves an explicit application number" do
      borrower = create(:borrower)
      loan_application = described_class.create!(
        borrower: borrower,
        application_number: "APP-0420",
        status: "open",
        borrower_full_name_snapshot: borrower.full_name,
        borrower_phone_number_snapshot: borrower.phone_number_normalized
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

  describe "snapshot immutability" do
    it "prevents changing borrower_full_name_snapshot on a persisted record" do
      loan_application = create(:loan_application)

      loan_application.borrower_full_name_snapshot = "Changed Name"

      expect(loan_application).not_to be_valid
      expect(loan_application.errors[:borrower_full_name_snapshot]).to include("cannot be changed after creation")
    end

    it "prevents changing borrower_phone_number_snapshot on a persisted record" do
      loan_application = create(:loan_application)

      loan_application.borrower_phone_number_snapshot = "+910000000000"

      expect(loan_application).not_to be_valid
      expect(loan_application.errors[:borrower_phone_number_snapshot]).to include("cannot be changed after creation")
    end

    it "allows initial creation with snapshot values" do
      loan_application = create(:loan_application)

      expect(loan_application).to be_persisted
      expect(loan_application.borrower_full_name_snapshot).to be_present
      expect(loan_application.borrower_phone_number_snapshot).to be_present
    end
  end

  describe "display helpers" do
    it "returns the snapshot value when present" do
      borrower = create(:borrower, full_name: "Asha Patel", phone_number: "+91 98765 43210")
      loan_application = create(:loan_application,
        borrower: borrower,
        borrower_full_name_snapshot: "Asha Patel",
        borrower_phone_number_snapshot: "+919876543210"
      )

      borrower.update!(full_name: "Asha R. Patel", phone_number: "+91 98765 99999")

      expect(loan_application.borrower_full_name_display).to eq("Asha Patel")
      expect(loan_application.borrower_phone_number_display).to eq("+919876543210")
    end

    it "falls back to live borrower data when snapshot is nil" do
      borrower = create(:borrower, full_name: "Asha Patel", phone_number: "+91 98765 43210")
      loan_application = build(:loan_application,
        borrower: borrower,
        borrower_full_name_snapshot: nil,
        borrower_phone_number_snapshot: nil
      )

      expect(loan_application.borrower_full_name_display).to eq("Asha Patel")
      expect(loan_application.borrower_phone_number_display).to eq("+919876543210")
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

  describe "associations" do
    subject(:loan_application) { build(:loan_application) }

    it { is_expected.to belong_to(:borrower) }
    it { is_expected.to have_many(:review_steps).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:loans).dependent(:restrict_with_exception) }
  end

  describe "application_number uniqueness" do
    it "enforces uniqueness of application_number" do
      create(:loan_application, application_number: "APP-0042")
      duplicate = build(:loan_application, application_number: "APP-0042")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:application_number]).to include("has already been taken")
    end
  end

  describe "#approvable?" do
    it "returns true when status is 'in progress' and all review steps are approved" do
      loan_application = create(:loan_application, :in_progress)
      create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "approved")
      create(:review_step, :request_details, loan_application:, status: "approved")
      create(:review_step, :verification, loan_application:, status: "approved")

      expect(loan_application).to be_approvable
    end

    it "returns false when not all review steps are approved" do
      loan_application = create(:loan_application, :in_progress)
      create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "initialized")
      create(:review_step, :request_details, loan_application:, status: "initialized")
      create(:review_step, :verification, loan_application:, status: "initialized")

      expect(loan_application).not_to be_approvable
    end

    it "returns false when status is not 'in progress'" do
      loan_application = create(:loan_application, status: "open")
      create(:review_step, :history_check, loan_application:, status: "approved")
      create(:review_step, :phone_screening, loan_application:, status: "approved")
      create(:review_step, :request_details, loan_application:, status: "approved")
      create(:review_step, :verification, loan_application:, status: "approved")

      expect(loan_application).not_to be_approvable
    end

    it "returns false when there are no review steps" do
      loan_application = create(:loan_application, :in_progress)

      expect(loan_application).not_to be_approvable
    end
  end

  describe "#rejectable?" do
    it "returns true for open applications" do
      expect(build(:loan_application, status: "open")).to be_rejectable
    end

    it "returns true for in-progress applications" do
      expect(build(:loan_application, status: "in progress")).to be_rejectable
    end

    it "returns false for already-decided applications" do
      expect(build(:loan_application, status: "approved")).not_to be_rejectable
      expect(build(:loan_application, status: "rejected")).not_to be_rejectable
      expect(build(:loan_application, status: "cancelled")).not_to be_rejectable
    end
  end

  describe "#cancellable?" do
    it "returns true for open applications" do
      expect(build(:loan_application, status: "open")).to be_cancellable
    end

    it "returns true for in-progress applications" do
      expect(build(:loan_application, status: "in progress")).to be_cancellable
    end

    it "returns false for already-decided applications" do
      expect(build(:loan_application, status: "approved")).not_to be_cancellable
      expect(build(:loan_application, status: "rejected")).not_to be_cancellable
      expect(build(:loan_application, status: "cancelled")).not_to be_cancellable
    end
  end
end
