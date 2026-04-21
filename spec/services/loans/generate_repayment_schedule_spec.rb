require "rails_helper"

RSpec.describe Loans::GenerateRepaymentSchedule do
  describe ".call" do
    let(:disbursement_date) { Date.new(2026, 4, 16) }

    it "generates a monthly schedule for an active loan and links the payments back to the loan" do
      loan = create(:loan, :active, :with_details, disbursement_date:)

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.loan).to eq(loan)
      expect(result.payments.size).to eq(12)
      expect(result.payments).to all(be_persisted)
      expect(result.payments).to all(have_attributes(loan_id: loan.id, status: "pending"))
      expect(result.payments.map(&:installment_number)).to eq((1..12).to_a)
      expect(result.payments.map(&:due_date).first).to eq(Date.new(2026, 5, 16))
      expect(result.payments.map(&:due_date).last).to eq(Date.new(2027, 4, 16))
      expect(loan.reload.payments.ordered).to eq(result.payments)
    end

    it "generates exactly tenure_in_months * 2 payments for bi-weekly schedules" do
      loan = create(
        :loan,
        :active,
        :with_details,
        disbursement_date:,
        repayment_frequency: "bi-weekly"
      )

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.payments.size).to eq(24)
      expect(result.payments.first.due_date).to eq(Date.new(2026, 4, 30))
      expect(result.payments.last.due_date).to eq(Date.new(2027, 3, 18))
    end

    it "generates exactly tenure_in_months * 4 payments for weekly schedules" do
      loan = create(
        :loan,
        :active,
        :with_details,
        disbursement_date:,
        repayment_frequency: "weekly"
      )

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.payments.size).to eq(48)
      expect(result.payments.first.due_date).to eq(Date.new(2026, 4, 23))
      expect(result.payments.last.due_date).to eq(Date.new(2027, 3, 18))
    end

    it "generates 18 payments for a 9-month bi-weekly loan" do
      loan = create(
        :loan,
        :active,
        :with_details,
        disbursement_date:,
        tenure_in_months: 9,
        repayment_frequency: "bi-weekly"
      )

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.payments.size).to eq(18)
      expect(result.payments.first.due_date).to eq(Date.new(2026, 4, 30))
      expect(result.payments.last.due_date).to eq(Date.new(2026, 12, 24))
    end

    it "calculates simple interest from the annual rate for rate-based loans" do
      loan = create(:loan, :active, :with_details, disbursement_date:)

      result = described_class.call(loan: loan)
      total_interest_cents = result.payments.sum(&:interest_amount_cents)
      total_amount_cents = result.payments.sum(&:total_amount_cents)

      expect(result).to be_success
      expect(total_interest_cents).to eq(562_500)
      expect(total_amount_cents).to eq(5_062_500)
      expect(result.payments.first.total_amount_cents).to eq(421_900)
      expect(result.payments.last.total_amount_cents).to eq(421_600)
    end

    it "uses the fixed total interest amount when that mode is selected" do
      loan = create(:loan, :active, :with_total_interest_details, disbursement_date:)

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.payments.sum(&:interest_amount_cents)).to eq(800_000)
      expect(result.payments.sum(&:total_amount_cents)).to eq(5_300_000)
    end

    it "keeps regular installment totals equal when principal and interest both have remainders" do
      loan = create(
        :loan,
        :active,
        disbursement_date:,
        principal_amount_cents: 1_000_00,
        tenure_in_months: 3,
        repayment_frequency: "monthly",
        interest_mode: "total_interest_amount",
        total_interest_amount_cents: 1_010_00
      )

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.payments.first(2).map(&:total_amount_cents)).to all(eq(670_00))
      expect(result.payments.last.total_amount_cents).to eq(670_00)
      expect(result.payments.sum(&:principal_amount_cents)).to eq(1_000_00)
      expect(result.payments.sum(&:interest_amount_cents)).to eq(1_010_00)
      expect(result.payments).to all(satisfy { |payment| payment.interest_amount_cents >= 0 })
    end

    it "keeps principal, interest, and total installment sums internally consistent" do
      loan = create(:loan, :active, :with_details, disbursement_date:)

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.payments.sum(&:principal_amount_cents)).to eq(loan.principal_amount_cents)
      expect(result.payments.sum(&:interest_amount_cents)).to eq(562_500)
      expect(result.payments.sum(&:total_amount_cents)).to eq(loan.principal_amount_cents + 562_500)
    end

    it "lets the last installment absorb rounding remainders" do
      loan = create(:loan, :active, :with_total_interest_details, disbursement_date:)

      result = described_class.call(loan: loan)
      regular_installments = result.payments.first(11)
      last_installment = result.payments.last

      expect(result).to be_success
      expect(regular_installments.map(&:total_amount_cents)).to all(eq(441_700))
      expect(last_installment.total_amount_cents).to eq(441_300)
      expect(result.payments.sum(&:total_amount_cents)).to eq(5_300_000)
      expect(result.payments.sum(&:principal_amount_cents)).to eq(loan.principal_amount_cents)
      expect(result.payments.sum(&:interest_amount_cents)).to eq(800_000)
      expect(result.payments).to all(satisfy { |payment| payment.interest_amount_cents >= 0 })
    end

    it "rounds regular installments to whole rupees (multiples of 100 paise)" do
      loan = create(:loan, :active, :with_total_interest_details, disbursement_date:)

      result = described_class.call(loan: loan)
      regular_installments = result.payments.first(11)

      expect(result).to be_success
      expect(regular_installments.map(&:total_amount_cents)).to all(satisfy { |c| (c % 100).zero? })
    end

    it "produces identical installments when the total divides evenly into whole rupees" do
      loan = create(
        :loan,
        :active,
        disbursement_date:,
        principal_amount_cents: 300_000,
        tenure_in_months: 3,
        repayment_frequency: "monthly",
        interest_mode: "total_interest_amount",
        total_interest_amount_cents: 60_000
      )

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.payments.map(&:total_amount_cents)).to all(eq(120_000))
    end

    it "applies banker's rounding at the rupee boundary (round half to even)" do
      loan = create(
        :loan,
        :active,
        disbursement_date:,
        principal_amount_cents: 300_150,
        tenure_in_months: 3,
        repayment_frequency: "monthly",
        interest_mode: "total_interest_amount",
        total_interest_amount_cents: 0
      )

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.payments.first.total_amount_cents).to eq(100_000)
      expect(result.payments.last.total_amount_cents).to eq(100_150)
      expect(result.payments.sum(&:total_amount_cents)).to eq(300_150)
    end

    it "blocks schedule generation when the loan is not active" do
      loan = create(:loan, :ready_for_disbursement, :with_details, disbursement_date:)

      result = described_class.call(loan: loan)

      expect(result).to be_blocked
      expect(result.error).to include("active")
      expect(loan.payments).to be_empty
    end

    it "blocks schedule generation when a schedule already exists" do
      loan = create(:loan, :active, :with_details, disbursement_date:)
      create(:payment, loan:)

      result = described_class.call(loan: loan)

      expect(result).to be_blocked
      expect(result.error).to include("already")
    end

    it "blocks schedule generation when the financial details are incomplete" do
      loan = create(
        :loan,
        :active,
        disbursement_date:,
        principal_amount: nil,
        tenure_in_months: nil,
        repayment_frequency: nil,
        interest_mode: nil
      )

      result = described_class.call(loan: loan)

      expect(result).to be_blocked
      expect(result.error).to include("financial details are incomplete")
      expect(loan.payments).to be_empty
    end

    it "blocks schedule generation when the interest details produce a negative total" do
      loan = create(
        :loan,
        :active,
        disbursement_date:,
        principal_amount_cents: 45_000,
        tenure_in_months: 12,
        repayment_frequency: "monthly",
        interest_mode: "total_interest_amount",
        total_interest_amount_cents: -1
      )

      result = described_class.call(loan: loan)

      expect(result).to be_blocked
      expect(result.error).to include("invalid")
      expect(loan.payments).to be_empty
    end

    it "blocks schedule generation when equal installments would round down to zero" do
      loan = create(
        :loan,
        :active,
        disbursement_date:,
        principal_amount_cents: 3,
        tenure_in_months: 12,
        repayment_frequency: "monthly",
        interest_mode: "total_interest_amount",
        total_interest_amount_cents: 0
      )

      result = described_class.call(loan: loan)

      expect(result).to be_blocked
      expect(result.error).to include("positive installments")
      expect(loan.payments).to be_empty
    end

    it "returns a blocked result when a concurrent schedule creation wins the race" do
      loan = create(:loan, :active, :with_details, disbursement_date:)
      payments_scope = loan.payments
      service = described_class.new(loan: loan)

      allow(loan).to receive(:payments).and_return(payments_scope)
      allow(described_class).to receive(:new).with(loan: loan).and_return(service)
      allow(payments_scope).to receive(:exists?).and_return(false, true)
      allow(service).to receive(:create_payments!).and_raise(ActiveRecord::RecordNotUnique, "duplicate payment schedule")

      result = described_class.call(loan: loan)

      expect(result).to be_blocked
      expect(result.error).to include("already exists")
    end
  end
end
