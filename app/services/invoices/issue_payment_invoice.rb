module Invoices
  class IssuePaymentInvoice < ApplicationService
    Result = Struct.new(:invoice, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(payment:)
      @payment = payment
    end

    def call
      return blocked("Payment must be completed before invoicing.") unless payment.completed?
      return blocked("A payment invoice already exists for this payment.") if payment.invoice.present?

      invoice = create_invoice!
      Result.new(invoice:)
    end

    private
      attr_reader :payment

      def blocked(message)
        Result.new(invoice: nil, error: message)
      end

      def create_invoice!
        Invoice.create_with_next_invoice_number!(
          loan: payment.loan,
          payment: payment,
          invoice_type: "payment",
          amount_cents: payment.total_amount_cents,
          currency: "INR",
          issued_on: payment.payment_date,
          notes: "Payment invoice for #{payment.loan.loan_number} · installment ##{payment.installment_number}"
        )
      end
  end
end
