module LoanApplications
  class InitializeReviewWorkflow < ApplicationService
    def initialize(loan_application:)
      @loan_application = loan_application
    end

    def call
      loan_application.with_lock do
        ReviewStep.workflow_definition.each do |definition|
          loan_application.review_steps.create_with(
            position: definition.position,
            status: "initialized"
          ).find_or_create_by!(step_key: definition.step_key)
        end
      end

      loan_application.review_steps.reset
      loan_application.review_steps
    end

    private
      attr_reader :loan_application
  end
end
