require "rails_helper"

RSpec.describe Loans::RefreshStatus do
  describe ".call" do
    let(:today) { Date.new(2026, 5, 1) }
    let(:admin) { create(:user, email_address: "admin@example.com") }

    def active_loan
      create(:loan, :active, :with_details, disbursement_date: today - 60.days)
    end

    def disbursed_loan
      loan = create(:loan, :ready_for_disbursement, :with_details)
      Loans::Disburse.call(loan: loan, disbursed_by: admin)
      loan.reload
    end

    def complete_all_payments!(loan, payment_date: Date.current)
      loan.payments.ordered.each do |payment|
        payment.update_columns(
          status: "completed",
          payment_date: payment_date,
          payment_mode: "cash",
          completed_at: Time.zone.now
        )
      end
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

    it "applies a late fee after transitioning a pending-past-due payment to overdue" do
      loan = active_loan
      payment = create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 1.day, late_fee_cents: 0)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to eq(:mark_overdue)
      expect(result.late_fees_applied).to eq(1)
      expect(payment.reload).to be_overdue
      expect(payment.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      expect(loan.reload).to be_overdue
    end

    it "is idempotent across repeated calls once the late fee has been applied" do
      loan = active_loan
      payment = create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 1.day, late_fee_cents: 0)

      first = described_class.call(loan: loan, today: today)
      second = described_class.call(loan: loan, today: today)

      expect(first.transitioned).to eq(:mark_overdue)
      expect(first.late_fees_applied).to eq(1)
      expect(second.transitioned).to be_nil
      expect(second.late_fees_applied).to eq(0)
      expect(payment.reload.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
    end

    it "applies only the missing late fees when some overdue installments were already assessed" do
      loan = create(:loan, :overdue, :with_details, disbursement_date: today - 60.days)
      already_assessed = create(
        :payment,
        :overdue,
        loan: loan,
        installment_number: 1,
        due_date: today - 10.days,
        late_fee_cents: Payments::LateFeePolicy.flat_fee_cents
      )
      newly_overdue = create(
        :payment,
        :pending,
        loan: loan,
        installment_number: 2,
        due_date: today - 2.days,
        late_fee_cents: 0
      )

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to be_nil
      expect(result.late_fees_applied).to eq(1)
      expect(already_assessed.reload.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      expect(newly_overdue.reload).to be_overdue
      expect(newly_overdue.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      expect(loan.reload).to be_overdue
    end

    it "reports changed when only a late fee is applied" do
      loan = create(:loan, :overdue, :with_details, disbursement_date: today - 60.days)
      create(:payment, :overdue, loan: loan, installment_number: 1, due_date: today - 5.days, late_fee_cents: 0)

      result = described_class.call(loan: loan, today: today)

      expect(result.transitioned).to be_nil
      expect(result.late_fees_applied).to eq(1)
      expect(result.changed?).to be(true)
    end

    it "no-ops when all pending payments are in the future" do
      loan = active_loan
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: today + 10.days)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to be_nil
      expect(loan.reload).to be_active
    end

    it "closes a disbursed loan when all generated payments are completed" do
      loan = disbursed_loan
      complete_all_payments!(loan)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to eq(:close)
      expect(result.late_fees_applied).to eq(0)
      expect(loan.reload).to be_closed
    end

    it "closes from overdue instead of resolving overdue when all payments are completed" do
      loan = disbursed_loan
      payments = loan.payments.ordered.to_a
      payments.first(payments.size - 1).each do |payment|
        payment.update_columns(
          status: "completed",
          payment_date: today,
          payment_mode: "cash",
          completed_at: Time.zone.now
        )
      end

      last_payment = payments.last
      last_payment.update_columns(status: "overdue", due_date: today - 5.days)
      loan.update_columns(status: "overdue")

      last_payment.update_columns(
        status: "completed",
        payment_date: today,
        payment_mode: "cash",
        completed_at: Time.zone.now
      )

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to eq(:close)
      expect(loan.reload).to be_closed
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

    it "does not close an active loan with no payments" do
      loan = active_loan

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_success
      expect(result.transitioned).to be_nil
      expect(loan.reload).to be_active
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
      expect(first.late_fees_applied).to eq(1)
      expect(second.transitioned).to be_nil
      expect(second.late_fees_applied).to eq(0)
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
      expect(result_after.late_fees_applied).to eq(1)
      expect(payment.reload).to be_overdue
      expect(loan.reload).to be_overdue
    end

    it "does not post to DoubleEntry during closure" do
      loan = disbursed_loan
      complete_all_payments!(loan)

      expect(DoubleEntry).not_to receive(:transfer)

      described_class.call(loan: loan, today: today)
    end

    it "returns blocked when close! raises ActiveRecord::RecordInvalid" do
      loan = disbursed_loan
      complete_all_payments!(loan)
      allow(loan).to receive(:close!).and_raise(ActiveRecord::RecordInvalid.new(loan))
      allow(Rails.logger).to receive(:warn)

      result = described_class.call(loan: loan, today: today)

      expect(result).to be_blocked
      expect(result.error).to eq(Loans::RefreshStatus::BLOCKED_INVALID_STATE)
      expect(Rails.logger).to have_received(:warn).with(/loan #{loan.id}/)
    end

    it "acquires a pessimistic lock around the loan refresh" do
      loan = disbursed_loan
      complete_all_payments!(loan)

      expect(loan).to receive(:with_lock).and_call_original

      described_class.call(loan: loan, today: today)
    end
  end
end
