require "rails_helper"

RSpec.describe Payment, type: :model do
  subject(:payment) { build(:payment) }

  it { is_expected.to belong_to(:loan) }

  describe "associations" do
    it "has one invoice resolving to the payment's own invoice" do
      loan = create(:loan, :active, :with_details)
      payment = create(:payment, :completed, loan: loan)
      create(:invoice, :disbursement, loan: loan)
      payment_invoice = create(:invoice, :payment, payment: payment)

      expect(payment.reload.invoice).to eq(payment_invoice)
    end

    it "prevents destroying a payment that has an invoice" do
      loan = create(:loan, :active, :with_details)
      payment = create(:payment, :completed, loan: loan)
      create(:invoice, :payment, payment: payment)

      expect { payment.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end

  describe "validations" do
    it "requires the core scheduling fields" do
      payment = build(
        :payment,
        loan: nil,
        installment_number: nil,
        due_date: nil,
        principal_amount_cents: nil,
        interest_amount_cents: nil,
        total_amount_cents: nil,
        status: nil
      )

      expect(payment).not_to be_valid
      expect(payment.errors[:loan]).to include("must exist")
      expect(payment.errors[:installment_number]).to include("can't be blank")
      expect(payment.errors[:due_date]).to include("can't be blank")
      expect(payment.errors[:principal_amount_cents]).to include("can't be blank")
      expect(payment.errors[:interest_amount_cents]).to include("can't be blank")
      expect(payment.errors[:total_amount_cents]).to include("can't be blank")
      expect(payment.errors[:status]).to include("can't be blank")
    end

    it "requires non-negative money values and a positive installment number" do
      payment = build(
        :payment,
        installment_number: 0,
        principal_amount_cents: -1,
        interest_amount_cents: -1,
        total_amount_cents: 0,
        late_fee_cents: -1
      )

      expect(payment).not_to be_valid
      expect(payment.errors[:installment_number]).to include("must be greater than 0")
      expect(payment.errors[:principal_amount_cents]).to include("must be greater than or equal to 0")
      expect(payment.errors[:interest_amount_cents]).to include("must be greater than or equal to 0")
      expect(payment.errors[:total_amount_cents]).to include("must be greater than 0")
      expect(payment.errors[:late_fee_cents]).to include("must be greater than or equal to 0")
    end

    it "supports the monetized schedule fields" do
      payment = build(
        :payment,
        principal_amount: 3_750,
        interest_amount: 468.75,
        total_amount: 4_218.75,
        late_fee: 15
      )

      expect(payment.principal_amount_cents).to eq(375_000)
      expect(payment.interest_amount_cents).to eq(46_875)
      expect(payment.total_amount_cents).to eq(421_875)
      expect(payment.late_fee_cents).to eq(1_500)
    end
  end

  describe "scopes" do
    it "orders installments by installment number" do
      loan = create(:loan, :active, :with_details)
      second = create(:payment, loan:, installment_number: 2, due_date: Date.new(2026, 6, 16))
      first = create(:payment, loan:, installment_number: 1, due_date: Date.new(2026, 5, 16))

      expect(described_class.ordered).to eq([ first, second ])
    end
  end

  describe "lifecycle" do
    it "defines the repayment state machine" do
      expect(described_class.aasm.states.map(&:name)).to eq([ :pending, :completed, :overdue ])
    end

    it "marks pending payments as completed" do
      payment = create(:payment, :pending)
      payment.payment_date = Date.current
      payment.payment_mode = "cash"
      payment.completed_at = Time.current

      payment.mark_completed!

      expect(payment.reload).to be_completed
    end

    it "marks overdue payments as completed" do
      payment = create(:payment, :overdue)
      payment.payment_date = Date.current
      payment.payment_mode = "cash"
      payment.completed_at = Time.current

      payment.mark_completed!

      expect(payment.reload).to be_completed
    end

    it "marks pending payments as overdue" do
      payment = create(:payment, :pending)

      payment.mark_overdue!

      expect(payment.reload).to be_overdue
    end

    it "raises on invalid transitions" do
      payment = create(:payment, :completed)

      expect { payment.mark_overdue! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "completion-context validations" do
    it "requires payment_date, payment_mode, and completed_at when completed" do
      payment = build(:payment, :pending)
      payment.status = "completed"
      payment.payment_date = nil
      payment.payment_mode = nil
      payment.completed_at = nil

      expect(payment).not_to be_valid
      expect(payment.errors[:payment_date]).to include("can't be blank")
      expect(payment.errors[:payment_mode]).to include("can't be blank")
      expect(payment.errors[:completed_at]).to include("can't be blank")
    end

    it "rejects unsupported payment modes when completed" do
      payment = build(:payment, :completed, payment_mode: "wire")

      expect(payment).not_to be_valid
      expect(payment.errors[:payment_mode]).to include("is not included in the list")
    end

    it "accepts every supported payment mode when completed" do
      Payment::PAYMENT_MODES.each do |mode|
        payment = build(:payment, :completed, payment_mode: mode)
        expect(payment).to be_valid, "expected #{mode} to be a valid payment mode"
      end
    end

    it "rejects a future payment_date when completed" do
      payment = build(:payment, :completed, payment_date: Date.current + 1.day)

      expect(payment).not_to be_valid
      expect(payment.errors[:payment_date]).to include("cannot be in the future")
    end
  end

  describe "#payment_mode_label" do
    it "humanizes the stored mode" do
      expect(build(:payment, :completed, payment_mode: "bank_transfer").payment_mode_label).to eq("Bank transfer")
    end

    it "returns nil when payment_mode is blank" do
      expect(build(:payment, :pending, payment_mode: nil).payment_mode_label).to be_nil
    end
  end

  describe "#readonly?" do
    it "returns false for new records" do
      expect(build(:payment, :pending)).not_to be_readonly
    end

    it "returns false for pending persisted records" do
      expect(create(:payment, :pending)).not_to be_readonly
    end

    it "returns false for overdue persisted records" do
      expect(create(:payment, :overdue)).not_to be_readonly
    end

    it "returns true for completed persisted records and blocks AR-level updates" do
      payment = create(:payment, :completed, notes: "original")

      expect(payment).to be_readonly
      expect { payment.update(notes: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(payment.reload.notes).to eq("original")
      expect { payment.update!(notes: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "does not block the pending -> overdue AASM transition" do
      payment = create(:payment, :pending, due_date: Date.current - 1.day)

      expect { payment.mark_overdue! }.not_to raise_error
      expect(payment.reload).to be_overdue
    end
  end

  describe "#editable?" do
    it "returns true while the payment is still pending" do
      expect(build(:payment, :pending)).to be_editable
    end

    it "returns true while the payment is overdue" do
      expect(build(:payment, :overdue)).to be_editable
    end

    it "returns false once the payment is completed" do
      expect(build(:payment, :completed)).not_to be_editable
    end
  end
end
