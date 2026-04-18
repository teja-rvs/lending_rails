require "rails_helper"

RSpec.describe Invoices::IssuePaymentInvoice do
  describe ".call" do
    it "creates a payment invoice for a completed payment" do
      loan = create(:loan, :active, :with_details)
      payment = create(:payment, :completed, loan:, installment_number: 1)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(result.invoice).to be_persisted
      expect(result.invoice.invoice_type).to eq("payment")
      expect(result.invoice.amount_cents).to eq(payment.total_amount_cents)
      expect(result.invoice.issued_on).to eq(payment.payment_date)
      expect(result.invoice.payment).to eq(payment)
      expect(result.invoice.loan).to eq(loan)
      expect(result.invoice.invoice_number).to match(/\AINV-\d{4,}\z/)
    end

    it "returns blocked when the payment is not completed" do
      payment = create(:payment, :pending)

      result = described_class.call(payment: payment)

      expect(result).to be_blocked
      expect(result.error).to include("must be completed")
      expect(result.invoice).to be_nil
    end

    it "returns blocked when the payment is overdue (not completed)" do
      payment = create(:payment, :overdue)

      result = described_class.call(payment: payment)

      expect(result).to be_blocked
      expect(result.error).to include("must be completed")
    end

    it "is idempotent when called twice for the same payment" do
      payment = create(:payment, :completed)

      first_result = described_class.call(payment: payment)
      expect(first_result).to be_success

      expect {
        @second_result = described_class.call(payment: payment)
      }.not_to change(Invoice, :count)

      expect(@second_result).to be_blocked
      expect(@second_result.error).to include("already exists")
      expect(payment.reload.invoice).to eq(first_result.invoice)
    end

    it "inherits issued_on from a backdated payment_date (fact, not today)" do
      backdated = Date.current - 30.days
      payment = create(:payment, :completed, payment_date: backdated)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(result.invoice.issued_on).to eq(backdated)
    end

    it "shares the INV-NNNN sequence with disbursement invoices" do
      loan_a = create(:loan, :active, :with_details)
      create(:invoice, :disbursement, loan: loan_a, invoice_number: "INV-0001")

      loan_b = create(:loan, :active, :with_details)
      payment = create(:payment, :completed, loan: loan_b)

      result = described_class.call(payment: payment)

      expect(result.invoice.invoice_number).to eq("INV-0002")
    end
  end
end
