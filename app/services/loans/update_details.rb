module Loans
  class UpdateDetails < ApplicationService
    Result = Struct.new(:loan, :error, keyword_init: true) do
      def success?
        error.blank? && loan&.errors&.none?
      end

      def blocked?
        error.present?
      end

      def locked?
        error == "locked"
      end
    end

    def initialize(loan:, attributes:)
      @loan = loan
      @attributes = attributes
    end

    def call
      loan.with_lock do
        unless loan.editable_details?
          loan.errors.add(:base, "These loan details can no longer be edited after disbursement.")
          return Result.new(loan:, error: "locked")
        end

        loan.assign_attributes(normalized_attributes)
        loan.save(context: :details_update)

        Result.new(loan:)
      end
    end

    private
      attr_reader :loan, :attributes

      def normalized_attributes
        attrs = attributes.to_h.with_indifferent_access

        case attrs[:interest_mode]
        when "rate"
          attrs[:total_interest_amount] = nil
        when "total_interest_amount"
          attrs[:interest_rate] = nil
        end

        attrs
      end
  end
end
