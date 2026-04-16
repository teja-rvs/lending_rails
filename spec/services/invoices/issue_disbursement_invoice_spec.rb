require "rails_helper"

RSpec.describe Invoices::IssueDisbursementInvoice do
  describe ".call" do
    it "creates a disbursement invoice for a loan with principal" do
      loan = create(:loan, :ready_for_disbursement, :with_details, disbursement_date: Date.current)

      result = described_class.call(loan: loan)

      expect(result).to be_success
      expect(result.invoice).to be_persisted
      expect(result.invoice.invoice_type).to eq("disbursement")
      expect(result.invoice.amount_cents).to eq(loan.principal_amount_cents)
      expect(result.invoice.issued_on).to eq(Date.current)
      expect(result.invoice.invoice_number).to match(/\AINV-\d{4,}\z/)
      expect(result.invoice.loan).to eq(loan)
    end

    it "returns blocked when principal amount is not set" do
      loan = create(:loan, :ready_for_disbursement)

      result = described_class.call(loan: loan)

      expect(result).to be_blocked
      expect(result.error).to include("Principal amount")
      expect(result.invoice).to be_nil
    end

    it "returns blocked when a disbursement invoice already exists (idempotency)" do
      loan = create(:loan, :ready_for_disbursement, :with_details)
      create(:invoice, loan: loan, invoice_type: "disbursement")

      result = described_class.call(loan: loan)

      expect(result).to be_blocked
      expect(result.error).to include("already exists")
    end

    it "generates sequential invoice numbers" do
      loan1 = create(:loan, :ready_for_disbursement, :with_details, disbursement_date: Date.current)
      loan2 = create(:loan, :ready_for_disbursement, :with_details, disbursement_date: Date.current)

      result1 = described_class.call(loan: loan1)
      result2 = described_class.call(loan: loan2)

      expect(result1.invoice.invoice_number).to eq("INV-0001")
      expect(result2.invoice.invoice_number).to eq("INV-0002")
    end
  end
end
