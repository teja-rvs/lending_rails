require "rails_helper"

RSpec.describe Dashboard::PortfolioSummaryQuery do
  describe ".call" do
    it "returns zeros when no data exists" do
      result = described_class.call

      expect(result.closed_loans_count).to eq(0)
      expect(result.total_disbursed_cents).to eq(0)
      expect(result.total_repayment_cents).to eq(0)
    end

    it "returns correct closed_loans_count" do
      create(:loan, :closed, :with_details)
      create(:loan, :closed, :with_details)
      create(:loan, :active, :with_details)

      result = described_class.call

      expect(result.closed_loans_count).to eq(2)
    end

    it "returns correct total_disbursed_cents from Invoice.disbursement scope" do
      loan = create(:loan, :active, :with_details)
      create(:invoice, :disbursement, loan: loan, amount_cents: 100_000)
      create(:invoice, :disbursement, loan: loan, amount_cents: 200_000)

      result = described_class.call

      expect(result.total_disbursed_cents).to eq(300_000)
    end

    it "returns correct total_repayment_cents from Invoice.payment scope" do
      loan = create(:loan, :active, :with_details)
      payment1 = create(:payment, :completed, loan: loan, installment_number: 1)
      payment2 = create(:payment, :completed, loan: loan, installment_number: 2)
      create(:invoice, :payment, payment: payment1, loan: loan, amount_cents: 50_000)
      create(:invoice, :payment, payment: payment2, loan: loan, amount_cents: 75_000)

      result = described_class.call

      expect(result.total_repayment_cents).to eq(125_000)
    end

    it "excludes invoices of the wrong invoice_type from the respective totals" do
      loan = create(:loan, :active, :with_details)
      payment = create(:payment, :completed, loan: loan, installment_number: 1)
      create(:invoice, :disbursement, loan: loan, amount_cents: 100_000)
      create(:invoice, :payment, payment: payment, loan: loan, amount_cents: 50_000)

      result = described_class.call

      expect(result.total_disbursed_cents).to eq(100_000)
      expect(result.total_repayment_cents).to eq(50_000)
    end
  end
end
