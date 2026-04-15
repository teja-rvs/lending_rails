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

    it "supports monetized principal and total interest amounts" do
      loan = build(:loan, principal_amount: 45_000, total_interest_amount: 8_500)

      expect(loan.principal_amount_cents).to eq(4_500_000)
      expect(loan.total_interest_amount_cents).to eq(850_000)
    end

    it "requires the editable loan details in the details_update context" do
      loan = build(:loan)

      expect(loan).not_to be_valid(:details_update)
      expect(loan.errors[:principal_amount]).to include("can't be blank")
      expect(loan.errors[:tenure_in_months]).to include("can't be blank")
      expect(loan.errors[:repayment_frequency]).to include("can't be blank")
      expect(loan.errors[:interest_mode]).to include("can't be blank")
    end

    it "requires a positive principal and tenure in the details_update context" do
      loan = build(
        :loan,
        principal_amount: 0,
        tenure_in_months: 0,
        repayment_frequency: "monthly",
        interest_mode: "rate",
        interest_rate: BigDecimal("12.5000")
      )

      expect(loan).not_to be_valid(:details_update)
      expect(loan.errors[:principal_amount]).to include("must be greater than 0")
      expect(loan.errors[:tenure_in_months]).to include("must be greater than 0")
    end

    it "requires an interest rate and forbids a total interest amount when the mode is rate" do
      loan = build(
        :loan,
        principal_amount: 45_000,
        tenure_in_months: 12,
        repayment_frequency: "monthly",
        interest_mode: "rate",
        interest_rate: nil,
        total_interest_amount: 8_000
      )

      expect(loan).not_to be_valid(:details_update)
      expect(loan.errors[:interest_rate]).to include("can't be blank")
      expect(loan.errors[:total_interest_amount]).to include("must be blank when interest mode is rate")
    end

    it "requires a total interest amount and forbids an interest rate when the mode is a total amount" do
      loan = build(
        :loan,
        principal_amount: 45_000,
        tenure_in_months: 12,
        repayment_frequency: "monthly",
        interest_mode: "total_interest_amount",
        interest_rate: BigDecimal("12.5000"),
        total_interest_amount: nil
      )

      expect(loan).not_to be_valid(:details_update)
      expect(loan.errors[:total_interest_amount]).to include("can't be blank")
      expect(loan.errors[:interest_rate]).to include("must be blank when interest mode is total interest amount")
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

    it "reports which states allow editable pre-disbursement details" do
      expect(build(:loan, :created)).to be_editable_details
      expect(build(:loan, :documentation_in_progress)).to be_editable_details
      expect(build(:loan, :ready_for_disbursement)).to be_editable_details
      expect(build(:loan, :active)).not_to be_editable_details
      expect(build(:loan, :overdue)).not_to be_editable_details
      expect(build(:loan, :closed)).not_to be_editable_details
    end

    it "formats the pre-disbursement summary helpers when details are present" do
      loan = build(:loan, :with_details)

      expect(loan.principal_amount_display).to eq("45000.00")
      expect(loan.tenure_display).to eq("12 months")
      expect(loan.repayment_frequency_label).to eq("Monthly")
      expect(loan.interest_mode_label).to eq("Interest rate")
      expect(loan.interest_display).to eq("12.5000%")
      expect(loan.notes_display).to eq("Borrower confirmed monthly repayment preference.")
    end

    it "returns placeholders when pre-disbursement details are missing" do
      loan = build(:loan)

      expect(loan.principal_amount_display).to eq("Not provided yet")
      expect(loan.tenure_display).to eq("Not provided yet")
      expect(loan.interest_display).to eq("Not provided yet")
      expect(loan.notes_display).to eq("Not provided yet")
    end

    it "formats total-interest display correctly" do
      loan = build(:loan, :with_total_interest_details)

      expect(loan.interest_mode_label).to eq("Total interest amount")
      expect(loan.interest_display).to eq("8000.00")
    end
  end

  describe "audit trail" do
    it "records versions with paper trail" do
      loan = create(:loan)

      expect(loan.versions.order(:created_at).pluck(:event)).to include("create")
    end
  end
end
