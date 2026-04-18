module LoanApplications
  class FilteredListQuery < ApplicationQuery
    def self.call(...)
      new(...).call
    end

    def initialize(scope: LoanApplication.all, status: nil, search: nil)
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
          validated = value.select { |s| LoanApplication::STATUSES.include?(s) }
          return validated.presence
        end

        candidate = value.to_s.squish.downcase.presence
        candidate if LoanApplication::STATUSES.include?(candidate)
      end

      def search_matches(relation)
        query = "%#{LoanApplication.sanitize_sql_like(search)}%"

        relation.joins(:borrower).where(
          "loan_applications.application_number ILIKE :query OR borrowers.full_name ILIKE :query",
          query:
        )
      end
  end
end
