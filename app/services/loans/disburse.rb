module Loans
  class Disburse < ApplicationService
    Result = Struct.new(:loan, :invoice, :payments, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(loan:, disbursed_by:)
      @loan = loan
      @disbursed_by = disbursed_by
    end

    def call
      clearing = DoubleEntry.account(:disbursement_clearing, scope: loan)
      receivable = DoubleEntry.account(:loan_receivable, scope: loan)

      invoice = nil
      payments = []
      failure_message = nil

      DoubleEntry.lock_accounts(clearing, receivable) do
        loan.lock!

        return blocked("This loan cannot be disbursed from its current state.") unless loan.may_disburse?

        readiness = Loans::EvaluateDisbursementReadiness.call(loan: loan)
        return blocked(readiness.blocked_summary) unless readiness.ready_for_disbursement_action?

        return blocked("Principal amount must be set before disbursement.") if loan.principal_amount.blank?
        return blocked("Net disbursement amount must be positive.") if loan.net_disbursement_amount_cents <= 0

        loan.disbursement_date = Date.current
        loan.disburse!

        invoice_result = Invoices::IssueDisbursementInvoice.call(loan: loan)
        if invoice_result.blocked?
          failure_message = invoice_result.error
          raise ActiveRecord::Rollback, invoice_result.error
        end

        invoice = invoice_result.invoice

        DoubleEntry.transfer(
          Money.new(loan.net_disbursement_amount_cents, "INR"),
          from: clearing,
          to: receivable,
          code: :disbursement,
          metadata: { loan_id: loan.id, invoice_id: invoice.id, disbursed_by: disbursed_by.id }
        )

        schedule_result = Loans::GenerateRepaymentSchedule.call(loan: loan)
        if schedule_result.blocked?
          failure_message = schedule_result.error
          raise ActiveRecord::Rollback, schedule_result.error
        end

        payments = schedule_result.payments
      end

      if invoice.present? && payments.any?
        Result.new(loan:, invoice:, payments:)
      else
        blocked("Disbursement failed — #{failure_message || 'invoice could not be created.'}")
      end
    end

    private
      attr_reader :loan, :disbursed_by

      def blocked(message)
        Result.new(loan:, invoice: nil, payments: [], error: message)
      end
  end
end
