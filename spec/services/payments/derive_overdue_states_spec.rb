require "rails_helper"

RSpec.describe Payments::DeriveOverdueStates do
  describe ".call" do
    let(:today) { Date.new(2026, 5, 1) }

    it "scopes derivation per loan and does not touch unrelated loans" do
      loan_a = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      loan_b = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      payment_a = create(:payment, :pending, loan: loan_a, installment_number: 1, due_date: today - 2.days)
      payment_b = create(:payment, :pending, loan: loan_b, installment_number: 1, due_date: today + 10.days)

      result = described_class.call(today: today)

      expect(result.transitioned_payments).to eq(1)
      expect(result.transitioned_loans).to eq(1)
      expect(result.late_fees_applied).to eq(1)
      expect(result.closed_loans).to eq(0)
      expect(payment_a.reload).to be_overdue
      expect(payment_a.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      expect(loan_a.reload).to be_overdue
      expect(payment_b.reload).to be_pending
      expect(loan_b.reload).to be_active
    end

    it "aggregates transitioned payments, loans, and late fees across multiple loans" do
      loan_a = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      loan_b = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      create(:payment, :pending, loan: loan_a, installment_number: 1, due_date: today - 2.days)
      create(:payment, :pending, loan: loan_b, installment_number: 1, due_date: today - 3.days)

      result = described_class.call(today: today)

      expect(result.transitioned_payments).to eq(2)
      expect(result.transitioned_loans).to eq(2)
      expect(result.late_fees_applied).to eq(2)
      expect(result.closed_loans).to eq(0)
    end

    it "is idempotent — a second call does not transition anything" do
      loan = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 2.days)

      described_class.call(today: today)
      result = described_class.call(today: today)

      expect(result.transitioned_payments).to eq(0)
      expect(result.transitioned_loans).to eq(0)
      expect(result.late_fees_applied).to eq(0)
      expect(result.closed_loans).to eq(0)
    end

    it "cheaply scans — does not invoke MarkOverdue on completed payments" do
      loan = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      5.times do |i|
        create(:payment, :completed, loan: loan, installment_number: i + 1, due_date: today - (30 - i).days)
      end

      expect(Payments::MarkOverdue).not_to receive(:call)

      result = described_class.call(today: today)

      expect(result.transitioned_payments).to eq(0)
      expect(result.transitioned_loans).to eq(0)
      expect(result.late_fees_applied).to eq(0)
      expect(result.closed_loans).to eq(0)
    end

    it "increments closed_loans when a per-loan refresh reports closure" do
      loan = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 2.days)
      close_result = Loans::RefreshStatus::Result.new(loan: loan, transitioned: :close, late_fees_applied: 0)

      allow(Loans::RefreshStatus).to receive(:call).and_return(close_result)

      result = described_class.call(today: today)

      expect(result.closed_loans).to eq(1)
      expect(result.transitioned_loans).to eq(1)
    end

    it "isolates refresh failures so one loan error does not abort the sweep" do
      failing_loan = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      healthy_loan = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      create(:payment, :pending, loan: failing_loan, installment_number: 1, due_date: today - 2.days)
      healthy_payment = create(:payment, :pending, loan: healthy_loan, installment_number: 1, due_date: today - 3.days)

      allow(Loans::RefreshStatus).to receive(:call).and_wrap_original do |original, loan:, today:|
        raise "boom" if loan == failing_loan

        original.call(loan: loan, today: today)
      end

      result = described_class.call(today: today)

      expect(result.failed_loans).to eq(1)
      expect(result.transitioned_payments).to eq(1)
      expect(result.transitioned_loans).to eq(1)
      expect(result.late_fees_applied).to eq(1)
      expect(healthy_payment.reload).to be_overdue
    end

    it "does not visit already-closed loans even when they have pathological pending payments" do
      closed_loan = create(:loan, :closed, :with_details, disbursement_date: today - 60.days)
      active_loan = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      create(:payment, :pending, loan: closed_loan, installment_number: 1, due_date: today - 2.days)
      create(:payment, :pending, loan: active_loan, installment_number: 1, due_date: today - 2.days)

      expect(Loans::RefreshStatus).to receive(:call).with(hash_including(loan: active_loan, today: today)).and_call_original
      expect(Loans::RefreshStatus).not_to receive(:call).with(hash_including(loan: closed_loan, today: today))

      described_class.call(today: today)
    end
  end
end
