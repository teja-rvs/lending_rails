require "rails_helper"

RSpec.describe Loans::RecordRepayment do
  let(:admin) { create(:user, email_address: "admin@example.com") }

  def disbursed_loan
    loan = create(:loan, :ready_for_disbursement, :with_details)
    Loans::Disburse.call(loan: loan, disbursed_by: admin)
    loan.reload
  end

  describe ".call" do
    it "completes the payment, issues a payment invoice, and posts the repayment ledger transfer" do
      loan = disbursed_loan
      payment = loan.payments.ordered.first

      result = described_class.call(
        payment: payment,
        payment_date: Date.current,
        payment_mode: "cash",
        notes: "on time"
      )

      expect(result).to be_success
      expect(result.payment.completed?).to be(true)
      expect(result.invoice).to be_persisted
      expect(result.invoice.invoice_type).to eq("payment")
      expect(result.invoice.payment).to eq(result.payment)
    end

    it "decrements the loan_receivable balance and grows repayment_received by the installment total" do
      loan = disbursed_loan
      payment = loan.payments.ordered.first

      described_class.call(
        payment: payment,
        payment_date: Date.current,
        payment_mode: "cash"
      )

      receivable = DoubleEntry.account(:loan_receivable, scope: loan)
      repayment = DoubleEntry.account(:repayment_received, scope: loan)

      expect(receivable.balance).to eq(Money.new(loan.principal_amount_cents - payment.total_amount_cents, "INR"))
      expect(repayment.balance).to eq(Money.new(payment.total_amount_cents, "INR"))
    end

    it "stamps ledger metadata with loan_id, payment_id, and invoice_id" do
      loan = disbursed_loan
      payment = loan.payments.ordered.first

      result = described_class.call(
        payment: payment,
        payment_date: Date.current,
        payment_mode: "cash"
      )

      line = DoubleEntry::Line.where(account: "repayment_received", scope: loan.id).last
      expect(line.metadata["loan_id"]).to eq(loan.id)
      expect(line.metadata["payment_id"]).to eq(payment.id)
      expect(line.metadata["invoice_id"]).to eq(result.invoice.id)
    end

    it "rolls back state, invoice, and ledger when MarkCompleted blocks (invalid payment_mode)" do
      loan = disbursed_loan
      payment = loan.payments.ordered.first
      invoice_count_before = Invoice.payment.count
      repayment_lines_before = DoubleEntry::Line.where(account: "repayment_received").count

      result = described_class.call(
        payment: payment,
        payment_date: Date.current,
        payment_mode: "wire_transfer"
      )

      expect(result).to be_blocked
      expect(result.error).to include("wire_transfer")
      expect(payment.reload).to be_pending
      expect(Invoice.payment.count).to eq(invoice_count_before)
      expect(DoubleEntry::Line.where(account: "repayment_received").count).to eq(repayment_lines_before)
    end

    it "rolls back the AASM transition when invoice issuance is stubbed to block" do
      loan = disbursed_loan
      payment = loan.payments.ordered.first

      blocked_result = Invoices::IssuePaymentInvoice::Result.new(invoice: nil, error: "fake failure")
      allow(Invoices::IssuePaymentInvoice).to receive(:call).and_return(blocked_result)

      invoice_count_before = Invoice.payment.count
      repayment_lines_before = DoubleEntry::Line.where(account: "repayment_received").count

      result = described_class.call(
        payment: payment,
        payment_date: Date.current,
        payment_mode: "cash"
      )

      expect(result).to be_blocked
      expect(result.error).to eq("fake failure")
      expect(payment.reload).to be_pending
      expect(Invoice.payment.count).to eq(invoice_count_before)
      expect(DoubleEntry::Line.where(account: "repayment_received").count).to eq(repayment_lines_before)
    end

    it "is idempotent: a second call on the same payment is blocked and leaves the ledger and invoice counts stable" do
      loan = disbursed_loan
      payment = loan.payments.ordered.first

      first = described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")
      expect(first).to be_success

      invoice_count_before = Invoice.payment.count
      repayment_lines_before = DoubleEntry::Line.where(account: "repayment_received", scope: loan.id).count

      second = described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")

      expect(second).to be_blocked
      expect(second.error).to include("already been completed")
      expect(Invoice.payment.count).to eq(invoice_count_before)
      expect(DoubleEntry::Line.where(account: "repayment_received", scope: loan.id).count).to eq(repayment_lines_before)
    end

    it "accumulates invoices and ledger balances across two consecutive repayments" do
      loan = disbursed_loan
      first_payment, second_payment = loan.payments.ordered.first(2)

      first_result = described_class.call(payment: first_payment, payment_date: Date.current, payment_mode: "cash")
      second_result = described_class.call(payment: second_payment, payment_date: Date.current, payment_mode: "cash")

      expect(first_result).to be_success
      expect(second_result).to be_success
      expect(first_result.invoice).not_to eq(second_result.invoice)
      expect(Invoice.payment.where(loan: loan).count).to eq(2)

      receivable = DoubleEntry.account(:loan_receivable, scope: loan)
      repayment = DoubleEntry.account(:repayment_received, scope: loan)
      total_repaid = first_payment.total_amount_cents + second_payment.total_amount_cents

      expect(receivable.balance).to eq(Money.new(loan.principal_amount_cents - total_repaid, "INR"))
      expect(repayment.balance).to eq(Money.new(total_repaid, "INR"))
    end

    it "uses DoubleEntry.lock_accounts as the outer boundary" do
      loan = disbursed_loan
      payment = loan.payments.ordered.first

      expect(DoubleEntry).to receive(:lock_accounts).and_call_original

      described_class.call(payment: payment, payment_date: Date.current, payment_mode: "cash")
    end
  end
end
