module Loans
  class RecordRepayment < ApplicationService
    Result = Struct.new(:payment, :invoice, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(payment:, payment_date:, payment_mode:, notes: nil)
      @payment = payment
      @payment_date = payment_date
      @payment_mode = payment_mode
      @notes = notes
    end

    def call
      loan = payment.loan
      receivable = DoubleEntry.account(:loan_receivable, scope: loan)
      repayment  = DoubleEntry.account(:repayment_received, scope: loan)

      invoice = nil
      failure_message = nil

      DoubleEntry.lock_accounts(receivable, repayment) do
        completion = Payments::MarkCompleted.call(
          payment: payment,
          payment_date: @payment_date,
          payment_mode: @payment_mode,
          notes: @notes
        )
        if completion.blocked?
          failure_message = completion.error
          raise ActiveRecord::Rollback, completion.error
        end

        invoice_result = Invoices::IssuePaymentInvoice.call(payment: payment)
        if invoice_result.blocked?
          failure_message = invoice_result.error
          raise ActiveRecord::Rollback, invoice_result.error
        end
        invoice = invoice_result.invoice

        DoubleEntry.transfer(
          Money.new(payment.total_amount_cents, "INR"),
          from: receivable,
          to: repayment,
          code: :repayment,
          metadata: { loan_id: loan.id, payment_id: payment.id, invoice_id: invoice.id }
        )
      end

      if invoice.present?
        Result.new(payment: payment, invoice: invoice)
      else
        blocked(failure_message || "Repayment could not be recorded.")
      end
    end

    private
      attr_reader :payment

      def blocked(message)
        Result.new(payment: payment, invoice: nil, error: message)
      end
  end
end
