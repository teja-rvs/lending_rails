module Loans
  class Disburse < ApplicationService
    Result = Struct.new(:loan, :invoice, :error, keyword_init: true) do
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

      DoubleEntry.lock_accounts(clearing, receivable) do
        loan.lock!

        return blocked("This loan cannot be disbursed from its current state.") unless loan.may_disburse?

        readiness = Loans::EvaluateDisbursementReadiness.call(loan: loan)
        return blocked(readiness.blocked_summary) unless readiness.ready_for_disbursement_action?

        return blocked("Principal amount must be set before disbursement.") if loan.principal_amount.blank?

        loan.disbursement_date = Date.current
        loan.disburse!

        invoice_result = Invoices::IssueDisbursementInvoice.call(loan: loan)
        if invoice_result.blocked?
          raise ActiveRecord::Rollback, invoice_result.error
        end

        invoice = invoice_result.invoice

        DoubleEntry.transfer(
          Money.new(loan.principal_amount_cents, "INR"),
          from: clearing,
          to: receivable,
          code: :disbursement,
          metadata: { loan_id: loan.id, invoice_id: invoice.id, disbursed_by: disbursed_by.id }
        )
      end

      if invoice.present?
        Result.new(loan:, invoice:)
      else
        blocked("Disbursement failed — invoice could not be created.")
      end
    end

    private
      attr_reader :loan, :disbursed_by

      def blocked(message)
        Result.new(loan:, invoice: nil, error: message)
      end
  end
end
