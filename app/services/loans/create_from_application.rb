module Loans
  class CreateFromApplication < ApplicationService
    Result = Struct.new(:loan, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(loan_application:, lock_application: true)
      @loan_application = loan_application
      @lock_application = lock_application
    end

    def call
      return call_without_lock unless lock_application

      loan_application.with_lock { call_without_lock }
    end

    private
      attr_reader :loan_application, :lock_application

      def blocked_result(error)
        Result.new(loan: nil, error:)
      end

      def call_without_lock
        return blocked_result("Application is not approved.") unless loan_application.status == "approved"
        return blocked_result("A loan already exists for this application.") if loan_application.loan.present?

        Result.new(loan: create_loan!)
      end

      def create_loan!
        Loan.create_with_next_loan_number!(
          loan_application:,
          borrower: loan_application.borrower,
          status: "created",
          borrower_full_name_snapshot: loan_application.borrower.full_name,
          borrower_phone_number_snapshot: loan_application.borrower.phone_number_normalized
        )
      end
  end
end
