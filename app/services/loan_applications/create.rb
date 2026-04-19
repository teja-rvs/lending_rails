module LoanApplications
  class Create < ApplicationService
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
        LoanApplication.transaction do
          loan_application = LoanApplication.create_with_next_application_number!(
            borrower:,
            status: "open",
            borrower_full_name_snapshot: borrower.full_name,
            borrower_phone_number_snapshot: borrower.phone_number_normalized
          )

          LoanApplications::InitializeReviewWorkflow.call(loan_application:)
          loan_application
        end
      end
  end
end
