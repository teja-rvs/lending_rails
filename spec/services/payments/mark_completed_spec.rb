require "rails_helper"

RSpec.describe Payments::MarkCompleted do
  let(:admin) { create(:user, email_address: "admin@example.com") }

  describe ".call" do
    it "completes a pending payment" do
      payment = create(:payment, :pending)

      result = described_class.call(
        payment: payment,
        payment_date: Date.current,
        payment_mode: "cash",
        notes: "Received in branch"
      )

      expect(result).to be_success
      expect(payment.reload).to be_completed
      expect(payment.payment_date).to eq(Date.current)
      expect(payment.payment_mode).to eq("cash")
      expect(payment.notes).to eq("Received in branch")
      expect(payment.completed_at).to be_present
    end

    it "completes an overdue payment" do
      payment = create(:payment, :overdue)

      result = described_class.call(
        payment: payment,
        payment_date: Date.current,
        payment_mode: "upi"
      )

      expect(result).to be_success
      expect(payment.reload).to be_completed
      expect(payment.payment_mode).to eq("upi")
    end

    it "is idempotent — a second call on the same payment is blocked" do
      payment = create(:payment, :pending)

      described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")
      first_completed_at = payment.reload.completed_at
      first_version_count = payment.versions.count

      result = described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")

      expect(result).to be_blocked
      expect(result.error).to include("already been completed")
      expect(payment.reload.completed_at).to eq(first_completed_at)
      expect(payment.versions.count).to eq(first_version_count)
    end

    it "returns the idempotency message when the payment becomes completed during the lock window" do
      payment = create(:payment, :pending)

      allow(payment).to receive(:reload).and_wrap_original do |original|
        Payment.connection.update(
          "UPDATE payments SET status = 'completed', payment_date = #{Payment.connection.quote(Date.current)}, " \
          "payment_mode = 'cash', completed_at = #{Payment.connection.quote(Time.current)} " \
          "WHERE id = #{Payment.connection.quote(payment.id)}"
        )
        original.call
      end

      result = described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")

      expect(result).to be_blocked
      expect(result.error).to eq(Payments::MarkCompleted::BLOCKED_ALREADY_COMPLETED)
    end

    it "blocks when payment_date is nil" do
      payment = create(:payment, :pending)

      result = described_class.call(payment: payment, payment_date: nil, payment_mode: "cash")

      expect(result).to be_blocked
      expect(result.error).to eq("Payment date is required.")
      expect(payment.reload).to be_pending
    end

    it "blocks when payment_date is in the future" do
      payment = create(:payment, :pending)

      result = described_class.call(
        payment: payment,
        payment_date: Date.current + 1.day,
        payment_mode: "cash"
      )

      expect(result).to be_blocked
      expect(result.error).to eq("Payment date cannot be in the future.")
    end

    it "blocks when payment_mode is blank" do
      payment = create(:payment, :pending)

      result = described_class.call(payment: payment, payment_date: Date.current, payment_mode: "  ")

      expect(result).to be_blocked
      expect(result.error).to eq("Payment mode is required.")
    end

    it "blocks when payment_mode is not supported" do
      payment = create(:payment, :pending)

      result = described_class.call(payment: payment, payment_date: Date.current, payment_mode: "wire_transfer")

      expect(result).to be_blocked
      expect(result.error).to eq("wire_transfer is not a supported payment mode.")
    end

    it "blocks when earlier installments are not yet completed" do
      loan = create(:loan, :active, :with_details)
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current + 1.month)
      later = create(:payment, :pending, loan: loan, installment_number: 2, due_date: Date.current + 2.months)

      result = described_class.call(payment: later, payment_date: Date.current, payment_mode: "cash")

      expect(result).to be_blocked
      expect(result.error).to eq(Payments::MarkCompleted::BLOCKED_OUT_OF_ORDER)
      expect(later.reload).to be_pending
    end

    it "allows completion when all earlier installments are already completed" do
      loan = create(:loan, :active, :with_details)
      create(:payment, :completed, loan: loan, installment_number: 1, due_date: Date.current - 1.month)
      second = create(:payment, :pending, loan: loan, installment_number: 2, due_date: Date.current + 1.month)

      result = described_class.call(payment: second, payment_date: Date.current, payment_mode: "cash")

      expect(result).to be_success
      expect(second.reload).to be_completed
    end

    it "allows the first installment to be completed regardless" do
      loan = create(:loan, :active, :with_details)
      first = create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.current + 1.month)
      create(:payment, :pending, loan: loan, installment_number: 2, due_date: Date.current + 2.months)

      result = described_class.call(payment: first, payment_date: Date.current, payment_mode: "cash")

      expect(result).to be_success
      expect(first.reload).to be_completed
    end

    it "blocks when AASM cannot transition" do
      payment = create(:payment, :pending)
      allow_any_instance_of(Payment).to receive(:may_mark_completed?).and_return(false)

      result = described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")

      expect(result).to be_blocked
      expect(result.error).to eq(Payments::MarkCompleted::BLOCKED_INVALID_STATE)
    end

    it "normalizes mixed-case and padded payment modes" do
      payment = create(:payment, :pending)

      result = described_class.call(payment: payment, payment_date: Date.current, payment_mode: " Cash ")

      expect(result).to be_success
      expect(payment.reload.payment_mode).to eq("cash")
    end

    it "accepts a past payment date" do
      payment = create(:payment, :pending)

      result = described_class.call(
        payment: payment,
        payment_date: Date.current - 30.days,
        payment_mode: "cash"
      )

      expect(result).to be_success
      expect(payment.reload.payment_date).to eq(Date.current - 30.days)
    end

    it "persists PaperTrail whodunnit when wrapped in PaperTrail.request" do
      payment = create(:payment, :pending)

      PaperTrail.request(whodunnit: admin.id) do
        described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")
      end

      expect(payment.reload.versions.last.whodunnit).to eq(admin.id.to_s)
    end

    it "acquires a pessimistic lock around the mutation" do
      payment = create(:payment, :pending)

      expect(payment).to receive(:with_lock).and_call_original

      described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")
    end

    it "blocks when payment_date is an unparseable string" do
      payment = create(:payment, :pending)

      result = described_class.call(payment: payment, payment_date: "not-a-date", payment_mode: "cash")

      expect(result).to be_blocked
      expect(result.error).to eq("Payment date is required.")
      expect(payment.reload).to be_pending
    end
  end
end
