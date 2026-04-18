module Payments
  class DeriveOverdueStates < ApplicationService
    Result = Struct.new(:transitioned_payments, :transitioned_loans, :failed_loans, :error, keyword_init: true) do
      def success?
        error.blank?
      end
    end

    def initialize(today: Date.current)
      @today = today.to_date
    end

    def call
      loan_ids = Payment.where(status: "pending").where("due_date < ?", @today).distinct.pluck(:loan_id)

      transitioned_payments = 0
      transitioned_loans = 0
      failed_loans = 0

      Loan.where(id: loan_ids, status: %w[active overdue]).find_each do |loan|
        before_overdue_count = loan.payments.where(status: "overdue").count
        result = Loans::RefreshStatus.call(loan: loan, today: @today)
        after_overdue_count = loan.payments.reload.where(status: "overdue").count
        transitioned_payments += [ after_overdue_count - before_overdue_count, 0 ].max
        transitioned_loans += 1 if result.changed?
      rescue => e
        failed_loans += 1
        Rails.logger.error("Payments::DeriveOverdueStates failed for loan #{loan.id}: #{e.class} #{e.message}")
      end

      Result.new(
        transitioned_payments: transitioned_payments,
        transitioned_loans: transitioned_loans,
        failed_loans: failed_loans
      )
    end
  end
end
