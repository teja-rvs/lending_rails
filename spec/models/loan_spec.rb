require "rails_helper"

RSpec.describe Loan do
  describe "validations" do
    it "requires borrower snapshot fields" do
      loan = build(
        :loan,
        borrower_full_name_snapshot: nil,
        borrower_phone_number_snapshot: nil
      )

      expect(loan).not_to be_valid
      expect(loan.errors[:borrower_full_name_snapshot]).to include("can't be blank")
      expect(loan.errors[:borrower_phone_number_snapshot]).to include("can't be blank")
    end

    it "requires a unique loan number" do
      create(:loan, loan_number: "LOAN-0001")
      loan = build(:loan, loan_number: "LOAN-0001")

      expect(loan).not_to be_valid
      expect(loan.errors[:loan_number]).to include("has already been taken")
    end
  end

  describe ".next_loan_number" do
    it "returns the next padded loan number" do
      create(:loan, loan_number: "LOAN-0001")
      create(:loan, loan_number: "LOAN-0012")
      create(:loan, loan_number: "OTHER-9999")

      expect(described_class.next_loan_number).to eq("LOAN-0013")
    end
  end

  describe ".create_with_next_loan_number!" do
    it "locks the loans table while allocating the next loan number" do
      borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
      create(:loan, borrower:, loan_number: "LOAN-0007")
      allow(described_class.connection).to receive(:execute).and_call_original

      loan = described_class.create_with_next_loan_number!(
        borrower:,
        status: "created",
        borrower_full_name_snapshot: borrower.full_name,
        borrower_phone_number_snapshot: borrower.phone_number_normalized
      )

      expect(loan.loan_number).to eq("LOAN-0008")
      expect(described_class.connection).to have_received(:execute).with(/LOCK TABLE .*loans.* IN EXCLUSIVE MODE/)
    end
  end

  describe "lifecycle" do
    it "defines the full AASM state vocabulary" do
      expect(described_class.aasm.states.map(&:name)).to eq(
        [
          :created,
          :documentation_in_progress,
          :ready_for_disbursement,
          :active,
          :overdue,
          :closed
        ]
      )
    end

    it "defaults new loans to the created state" do
      expect(build(:loan)).to be_created
    end

    it "moves from created to documentation in progress" do
      loan = create(:loan, :created)

      expect(loan.may_begin_documentation?).to be(true)

      loan.begin_documentation!

      expect(loan.reload).to be_documentation_in_progress
    end

    it "moves from documentation in progress to ready for disbursement" do
      loan = create(:loan, :documentation_in_progress)

      loan.complete_documentation!

      expect(loan.reload).to be_ready_for_disbursement
    end

    it "moves from ready for disbursement to active" do
      loan = create(:loan, :ready_for_disbursement)

      loan.disburse!

      expect(loan.reload).to be_active
    end

    it "moves from active to overdue and back again" do
      loan = create(:loan, :active)

      loan.mark_overdue!
      expect(loan.reload).to be_overdue

      loan.resolve_overdue!
      expect(loan.reload).to be_active
    end

    it "allows closing an overdue loan" do
      loan = create(:loan, :overdue)

      loan.close!

      expect(loan.reload).to be_closed
    end

    it "raises on invalid transitions" do
      loan = create(:loan, :created)

      expect { loan.disburse! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "display helpers" do
    it "returns the expected tones for lifecycle states" do
      expect(build(:loan, :created).status_tone).to eq(:neutral)
      expect(build(:loan, :documentation_in_progress).status_tone).to eq(:warning)
      expect(build(:loan, :ready_for_disbursement).status_tone).to eq(:success)
      expect(build(:loan, :active).status_tone).to eq(:success)
      expect(build(:loan, :overdue).status_tone).to eq(:danger)
      expect(build(:loan, :closed).status_tone).to eq(:neutral)
    end

    it "humanizes the status label" do
      expect(build(:loan, :documentation_in_progress).status_label).to eq("Documentation In Progress")
      expect(build(:loan, :ready_for_disbursement).status_label).to eq("Ready For Disbursement")
    end

    it "reports the next lifecycle stage for overdue and closed loans correctly" do
      expect(build(:loan, :overdue).next_lifecycle_stage_label).to eq("Active")
      expect(build(:loan, :closed).next_lifecycle_stage_label).to eq("Closed")
    end
  end

  describe "audit trail" do
    it "records versions with paper trail" do
      loan = create(:loan)

      expect(loan.versions.order(:created_at).pluck(:event)).to include("create")
    end
  end
end
