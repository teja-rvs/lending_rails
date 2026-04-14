module LoanApplications
  class Cancel < ApplicationService
    Result = Struct.new(:loan_application, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(loan_application:, decision_notes: nil)
      @loan_application = loan_application
      @decision_notes = decision_notes
    end

    def call
      loan_application.with_lock do
        return blocked_result("This application has already reached a final decision.") unless loan_application.cancellable?

        loan_application.update!(status: "cancelled", decision_notes:)
        Result.new(loan_application:)
      end
    end

    private
      attr_reader :loan_application, :decision_notes

      def blocked_result(error)
        Result.new(loan_application:, error:)
      end
  end
end
