require "rails_helper"

RSpec.describe Loans::RefreshStatus do
  describe ".call" do
    let(:today) { Date.new(2026, 5, 1) }

    def active_loan
      create(:loan, :active, :with_details, disbursement_date: today - 60.days)
    end

    it "marks a loan overdue when it has a pending-past-due payment" do
      loan = active_loan
      payment = create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 1.day)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to eq(:mark_overdue)
      expect(payment.reload).to be_overdue
      expect(loan.reload).to be_overdue
    end

    it "no-ops when all pending payments are in the future" do
      loan = active_loan
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: today + 10.days)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to be_nil
      expect(loan.reload).to be_active
    end

    it "does not fire close on an active loan whose payments are all completed (closure is out of scope)" do
      loan = active_loan
      create(:payment, :completed, loan: loan, installment_number: 1, due_date: today - 30.days)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to be_nil
      expect(loan.reload).to be_active
    end

    it "back-flips an overdue loan to active when no payment is overdue or pending-past-due" do
      loan = create(:loan, :overdue, :with_details, disbursement_date: today - 60.days)
      create(:payment, :completed, loan: loan, installment_number: 1, due_date: today - 30.days)
      create(:payment, :pending, loan: loan, installment_number: 2, due_date: today + 10.days)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to eq(:resolve_overdue)
      expect(loan.reload).to be_active
    end

    it "does not back-flip when a still-pending-past-due payment slips through (it will be freshly marked overdue instead)" do
      loan = create(:loan, :overdue, :with_details, disbursement_date: today - 60.days)
      still_pending = create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 3.days)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to be_nil
      expect(still_pending.reload).to be_overdue
      expect(loan.reload).to be_overdue
    end

    it "no-ops on a closed loan without raising" do
      loan = create(:loan, :closed, :with_details, disbursement_date: today - 60.days)

      expect {
        result = described_class.call(loan: loan, today: today)
        expect(result).to be_success
        expect(result.transitioned).to be_nil
      }.not_to raise_error

      expect(loan.reload).to be_closed
    end

    it "no-ops on a ready_for_disbursement loan" do
      loan = create(:loan, :ready_for_disbursement, :with_details)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to be_nil
      expect(loan.reload).to be_ready_for_disbursement
    end

    it "is idempotent across repeated calls" do
      loan = active_loan
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 1.day)

      first = described_class.call(loan: loan, today: today)
      second = described_class.call(loan: loan, today: today)

      expect(first.transitioned).to eq(:mark_overdue)
      expect(second.transitioned).to be_nil
    end

    it "produces opposite results with injected today before vs after the due date" do
      loan = active_loan
      payment = create(:payment, :pending, loan: loan, installment_number: 1, due_date: today)

      result_before = described_class.call(loan: loan, today: today - 1.day)
      expect(result_before.transitioned).to be_nil
      expect(payment.reload).to be_pending
      expect(loan.reload).to be_active

      result_after = described_class.call(loan: loan, today: today + 1.day)
      expect(result_after.transitioned).to eq(:mark_overdue)
      expect(payment.reload).to be_overdue
      expect(loan.reload).to be_overdue
    end

    it "acquires a pessimistic lock around the loan refresh" do
      loan = active_loan
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 1.day)

      expect(loan).to receive(:with_lock).and_call_original

      described_class.call(loan: loan, today: today)
    end
  end
end
