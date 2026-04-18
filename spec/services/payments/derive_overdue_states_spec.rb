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
      expect(payment_a.reload).to be_overdue
      expect(loan_a.reload).to be_overdue
      expect(payment_b.reload).to be_pending
      expect(loan_b.reload).to be_active
    end

    it "is idempotent — a second call does not transition anything" do
      loan = create(:loan, :active, :with_details, disbursement_date: today - 60.days)
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: today - 2.days)

      described_class.call(today: today)
      result = described_class.call(today: today)

      expect(result.transitioned_payments).to eq(0)
      expect(result.transitioned_loans).to eq(0)
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
    end
  end
end
