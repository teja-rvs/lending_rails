require "rails_helper"

RSpec.describe Payments::ApplyLateFee do
  describe ".call" do
    it "applies the flat late fee to an overdue payment" do
      payment = create(:payment, :overdue, due_date: Date.current - 5.days, late_fee_cents: 0)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(result).to be_applied
      expect(payment.reload.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
    end

    it "is idempotent when the late fee has already been applied" do
      payment = create(:payment, :overdue, due_date: Date.current - 5.days, late_fee_cents: 2_500)
      version_count = payment.versions.where(event: "update").count

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(payment.reload.late_fee_cents).to eq(2_500)
      expect(payment.versions.where(event: "update").count).to eq(version_count)
    end

    it "no-ops on a pending payment" do
      payment = create(:payment, :pending, due_date: Date.current - 5.days, late_fee_cents: 0)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(result).not_to be_applied
      expect(payment.reload.late_fee_cents).to eq(0)
      expect(payment).to be_pending
    end

    it "no-ops on a completed payment without raising ActiveRecord::ReadOnlyRecord" do
      payment = create(:payment, :completed, due_date: Date.current - 5.days, late_fee_cents: 0)

      expect {
        result = described_class.call(payment: payment)
        expect(result).to be_success
        expect(result).not_to be_applied
      }.not_to raise_error

      expect(payment.reload.late_fee_cents).to eq(0)
      expect(payment).to be_completed
    end

    it "acquires a pessimistic lock around the mutation" do
      payment = create(:payment, :overdue, due_date: Date.current - 5.days, late_fee_cents: 0)

      expect(payment).to receive(:with_lock).and_call_original

      described_class.call(payment: payment)
    end

    it "does not modify the payment status" do
      payment = create(:payment, :overdue, due_date: Date.current - 5.days, late_fee_cents: 0)

      described_class.call(payment: payment)

      expect(payment.reload).to be_overdue
    end

    it "does not modify total_amount_cents" do
      payment = create(:payment, :overdue, due_date: Date.current - 5.days, late_fee_cents: 0, total_amount_cents: 421_875)

      described_class.call(payment: payment)

      expect(payment.reload.total_amount_cents).to eq(421_875)
    end

    it "does not modify principal_amount_cents or interest_amount_cents" do
      payment = create(
        :payment,
        :overdue,
        due_date: Date.current - 5.days,
        late_fee_cents: 0,
        principal_amount_cents: 375_000,
        interest_amount_cents: 46_875
      )

      described_class.call(payment: payment)

      payment.reload
      expect(payment.principal_amount_cents).to eq(375_000)
      expect(payment.interest_amount_cents).to eq(46_875)
    end

    it "returns blocked and logs a warning when the update is invalid" do
      payment = create(:payment, :overdue, due_date: Date.current - 5.days, late_fee_cents: 0)
      allow(payment).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(payment))
      allow(Rails.logger).to receive(:warn)

      result = described_class.call(payment: payment)

      expect(result).to be_blocked
      expect(result.error).to eq("Late fee could not be applied.")
      expect(Rails.logger).to have_received(:warn).with(/payment #{payment.id}/)
    end

    it "records a PaperTrail update when the fee is first applied" do
      payment = create(:payment, :overdue, due_date: Date.current - 5.days, late_fee_cents: 0)

      expect {
        described_class.call(payment: payment)
      }.to change { payment.reload.versions.where(event: "update").count }.by(1)

      expect(payment.versions.last.event).to eq("update")
    end

    it "exposes a deterministic positive integer flat-fee contract" do
      expect(Payments::LateFeePolicy.flat_fee_cents).to be_a(Integer)
      expect(Payments::LateFeePolicy.flat_fee_cents).to be > 0
      expect(Payments::LateFeePolicy.flat_fee_cents).to eq(2_500)
    end
  end
end
