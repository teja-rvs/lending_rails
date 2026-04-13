module LoanApplications
  class UpdateDetails < ApplicationService
    Result = Struct.new(:loan_application, :locked, keyword_init: true) do
      def success?
        loan_application.errors.empty?
      end

      def locked?
        locked
      end
    end

    def initialize(loan_application:, attributes:)
      @loan_application = loan_application
      @attributes = attributes
    end

    def call
      return locked_result unless loan_application.editable_pre_decision_details?

      loan_application.assign_attributes(attributes)
      loan_application.valid?(:details_update)
      loan_application.save(context: :details_update) if loan_application.errors.empty?

      Result.new(loan_application:, locked: false)
    end

    private
      attr_reader :loan_application, :attributes

      def locked_result
        loan_application.errors.add(:base, "These request details can no longer be edited after a final decision.")
        Result.new(loan_application:, locked: true)
      end
  end
end
