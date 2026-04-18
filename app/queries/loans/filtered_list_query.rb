module Loans
  class FilteredListQuery < ApplicationQuery
    def self.call(...)
      new(...).call
    end

    def initialize(scope: Loan.all, status: nil, search: nil)
      @scope = scope
      @status = normalized_status(status)
      @search = search.to_s.squish
    end

    def call
      relation = ordered_scope
      relation = relation.where(status:) if status.present?
      relation = search_matches(relation) if search.present?
      relation
    end

    private
      attr_reader :scope, :status, :search

      def ordered_scope
        scope.includes(:borrower).order(created_at: :desc, id: :desc)
      end

      def normalized_status(value)
        if value.is_a?(Array)
          valid_statuses = Loan.aasm.states.map { |state| state.name.to_s }
          validated = value.select { |s| valid_statuses.include?(s) }
          return validated.presence
        end

        candidate = value.to_s.squish.downcase.presence
        candidate if Loan.aasm.states.map { |state| state.name.to_s }.include?(candidate)
      end

      def search_matches(relation)
        query = "%#{Loan.sanitize_sql_like(search)}%"

        relation.joins(:borrower).where(
          "loans.loan_number ILIKE :query OR borrowers.full_name ILIKE :query",
          query:
        )
      end
  end
end
