require "rails_helper"

RSpec.describe Loans::Disburse do
  let(:admin) { create(:user, email_address: "admin@example.com") }

  describe ".call" do
    it "disburses a ready-for-disbursement loan with complete details" do
      loan = create(:loan, :ready_for_disbursement, :with_details)

      result = described_class.call(loan: loan, disbursed_by: admin)

      expect(result).to be_success
      expect(loan.reload).to be_active
      expect(loan.disbursement_date).to eq(Date.current)
      expect(result.invoice).to be_persisted
      expect(result.payments.size).to eq(12)
      expect(result.payments).to all(be_persisted)
      expect(result.invoice.invoice_type).to eq("disbursement")
      expect(result.invoice.amount_cents).to eq(loan.principal_amount_cents)
    end

    it "posts double_entry accounting entries on disbursement" do
      loan = create(:loan, :ready_for_disbursement, :with_details)

      described_class.call(loan: loan, disbursed_by: admin)

      receivable = DoubleEntry.account(:loan_receivable, scope: loan)
      clearing = DoubleEntry.account(:disbursement_clearing, scope: loan)

      expect(receivable.balance).to eq(Money.new(loan.principal_amount_cents, "INR"))
      expect(clearing.balance).to eq(Money.new(-loan.principal_amount_cents, "INR"))
    end

    it "records metadata on the double_entry line items" do
      loan = create(:loan, :ready_for_disbursement, :with_details)

      result = described_class.call(loan: loan, disbursed_by: admin)

      line = DoubleEntry::Line.where(account: "loan_receivable", scope: loan.id).last
      expect(line.metadata["loan_id"]).to eq(loan.id)
      expect(line.metadata["invoice_id"]).to eq(result.invoice.id)
      expect(line.metadata["disbursed_by"]).to eq(admin.id)
    end

    it "blocks disbursement when the loan is not in ready_for_disbursement state" do
      loan = create(:loan, :created, :with_details)

      result = described_class.call(loan: loan, disbursed_by: admin)

      expect(result).to be_blocked
      expect(result.error).to include("cannot be disbursed")
      expect(loan.reload).to be_created
    end

    it "blocks disbursement when readiness checks fail" do
      loan = create(:loan, :ready_for_disbursement)

      result = described_class.call(loan: loan, disbursed_by: admin)

      expect(result).to be_blocked
      expect(result.error).to include("Disbursement is blocked")
      expect(loan.reload).to be_ready_for_disbursement
    end

    it "blocks disbursement when principal is not set" do
      loan = create(:loan, :ready_for_disbursement,
        tenure_in_months: 12,
        repayment_frequency: "monthly",
        interest_mode: "rate",
        interest_rate: BigDecimal("12.5000"))

      result = described_class.call(loan: loan, disbursed_by: admin)

      expect(result).to be_blocked
      expect(loan.reload).to be_ready_for_disbursement
    end

    it "does not create an invoice or accounting entries when disbursement is blocked" do
      loan = create(:loan, :created, :with_details)

      expect {
        described_class.call(loan: loan, disbursed_by: admin)
      }.not_to change(Invoice, :count)
    end

    it "rolls back the state change when invoice creation is blocked" do
      loan = create(:loan, :ready_for_disbursement, :with_details)
      create(:invoice, :disbursement, loan: loan)

      expect {
        @result = described_class.call(loan: loan, disbursed_by: admin)
      }.not_to change(DoubleEntry::Line, :count)

      result = @result

      expect(result).to be_blocked
      expect(result.error).to include("Disbursement failed")
      expect(loan.reload).to be_ready_for_disbursement
      expect(loan.disbursement_date).to be_nil
      expect(loan.invoices.disbursement.count).to eq(1)
    end

    it "rolls back the disbursement when repayment schedule generation is blocked" do
      loan = create(:loan, :ready_for_disbursement, :with_details)
      blocked_result = Loans::GenerateRepaymentSchedule::Result.new(
        loan:,
        payments: [],
        error: "Repayment schedule could not be generated."
      )

      allow(Loans::GenerateRepaymentSchedule).to receive(:call).with(loan: loan).and_return(blocked_result)

      expect {
        @result = described_class.call(loan: loan, disbursed_by: admin)
      }.not_to change(DoubleEntry::Line, :count)

      result = @result

      expect(result).to be_blocked
      expect(result.error).to include("Disbursement failed")
      expect(loan.reload).to be_ready_for_disbursement
      expect(loan.disbursement_date).to be_nil
      expect(loan.invoices).to be_empty
      expect(loan.payments).to be_empty
    end

    it "is idempotent: second disbursement attempt on an active loan is blocked" do
      loan = create(:loan, :ready_for_disbursement, :with_details)

      first_result = described_class.call(loan: loan, disbursed_by: admin)
      expect(first_result).to be_success

      second_result = described_class.call(loan: loan, disbursed_by: admin)
      expect(second_result).to be_blocked
      expect(second_result.error).to include("cannot be disbursed")
    end
  end
end
