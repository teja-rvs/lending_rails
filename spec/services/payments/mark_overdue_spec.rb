require "rails_helper"

RSpec.describe Payments::MarkOverdue do
  describe ".call" do
    let(:today) { Date.new(2026, 5, 1) }

    it "marks a pending payment overdue when due_date < today" do
      payment = create(:payment, :pending, due_date: today - 1.day)

      result = described_class.call(payment: payment, today: today)

      expect(result).to be_success
      expect(payment.reload).to be_overdue
    end

    it "is idempotent on an already-overdue payment" do
      payment = create(:payment, :overdue, due_date: today - 5.days)

      result = described_class.call(payment: payment, today: today)

      expect(result).to be_success
      expect(payment.reload).to be_overdue
      expect(payment.status_previously_changed?).to be false
    end

    it "no-ops on a completed payment without raising ActiveRecord::ReadOnlyRecord" do
      payment = create(:payment, :completed, due_date: today - 10.days)

      expect {
        result = described_class.call(payment: payment, today: today)
        expect(result).to be_success
      }.not_to raise_error

      expect(payment.reload).to be_completed
    end

    it "no-ops when due_date == today (overdue is strictly after the due date)" do
      payment = create(:payment, :pending, due_date: today)

      result = described_class.call(payment: payment, today: today)

      expect(result).to be_success
      expect(payment.reload).to be_pending
    end

    it "no-ops when due_date > today" do
      payment = create(:payment, :pending, due_date: today + 3.days)

      result = described_class.call(payment: payment, today: today)

      expect(result).to be_success
      expect(payment.reload).to be_pending
    end

    it "works when due_date == today and the injected today is advanced one day" do
      payment = create(:payment, :pending, due_date: today)

      result = described_class.call(payment: payment, today: today + 1.day)

      expect(result).to be_success
      expect(payment.reload).to be_overdue
    end

    it "returns blocked with the documented error when may_mark_overdue? is false" do
      payment = create(:payment, :pending, due_date: today - 1.day)
      allow(payment).to receive(:may_mark_overdue?).and_return(false)

      result = described_class.call(payment: payment, today: today)

      expect(result).to be_blocked
      expect(result.error).to eq(Payments::MarkOverdue::BLOCKED_INVALID_STATE)
    end

    it "acquires a pessimistic lock around the mutation" do
      payment = create(:payment, :pending, due_date: today - 1.day)

      expect(payment).to receive(:with_lock).and_call_original

      described_class.call(payment: payment, today: today)
    end

    it "records a PaperTrail version capturing the status transition" do
      payment = create(:payment, :pending, due_date: today - 1.day)

      expect {
        described_class.call(payment: payment, today: today)
      }.to change { payment.reload.versions.where(event: "update").count }.by(1)
    end
  end
end
