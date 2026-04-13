module LoanApplications
  class Create < ApplicationService
    MAX_APPLICATION_NUMBER_RETRIES = 3

    Result = Struct.new(:loan_application, :eligibility, keyword_init: true) do
      def success?
        loan_application.persisted?
      end
    end

    def initialize(borrower:)
      @borrower = borrower
    end

    def call
      return blocked_result unless eligibility.eligible?

      Result.new(
        loan_application: create_loan_application!,
        eligibility:
      )
    end

    private
      attr_reader :borrower

      def blocked_result
        loan_application = borrower.loan_applications.build(status: "open")
        loan_application.errors.add(:base, "A new application cannot be started for this borrower right now.")

        Result.new(loan_application:, eligibility:)
      end

      def eligibility
        @eligibility ||= Borrowers::HistoryQuery.call(id: borrower.id).eligibility
      end

      def create_loan_application!
        attempts = 0

        begin
          attempts += 1

          LoanApplication.create!(
            borrower:,
            status: "open",
            borrower_full_name_snapshot: borrower.full_name,
            borrower_phone_number_snapshot: borrower.phone_number_normalized
          )
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
          raise unless duplicate_application_number_error?(error) && attempts < MAX_APPLICATION_NUMBER_RETRIES

          retry
        end
      end

      def duplicate_application_number_error?(error)
        return true if error.is_a?(ActiveRecord::RecordNotUnique)

        error.record.errors.of_kind?(:application_number, :taken)
      end
  end
end
