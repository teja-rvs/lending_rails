module LoanApplications
  class Approve < ApplicationService
    Result = Struct.new(:loan_application, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(loan_application:)
      @loan_application = loan_application
    end

    def call
      loan_application.with_lock do
        return blocked_result(blocked_error) unless loan_application.approvable?

        loan_application.update!(status: "approved")
        Result.new(loan_application:)
      end
    end

    private
      attr_reader :loan_application

      def blocked_result(error)
        Result.new(loan_application:, error:)
      end

      def blocked_error
        return "This application has already reached a final decision." unless loan_application.editable_pre_decision_details?
        return "This application can only be approved after review has started." unless loan_application.status == "in progress"

        "This application can only be approved after every review step is approved."
      end
  end
end
