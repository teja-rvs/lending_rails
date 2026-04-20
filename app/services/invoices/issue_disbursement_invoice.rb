module Invoices
  class IssueDisbursementInvoice < ApplicationService
    Result = Struct.new(:invoice, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(loan:)
      @loan = loan
    end

    def call
      return blocked("Principal amount is not set on this loan.") if loan.principal_amount.blank?
      return blocked("Net disbursement amount must be positive.") if loan.net_disbursement_amount_cents <= 0
      return blocked("A disbursement invoice already exists for this loan.") if loan.invoices.disbursement.exists?

      invoice = create_invoice!
      Result.new(invoice:)
    end

    private
      attr_reader :loan

      def blocked(message)
        Result.new(invoice: nil, error: message)
      end

      def create_invoice!
        Invoice.create_with_next_invoice_number!(
          loan:,
          invoice_type: "disbursement",
          amount_cents: loan.net_disbursement_amount_cents,
          currency: "INR",
          issued_on: loan.disbursement_date || Date.current,
          notes: "Disbursement invoice for #{loan.loan_number}"
        )
      end
  end
end
