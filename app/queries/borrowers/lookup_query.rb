module Borrowers
  class LookupQuery < ApplicationQuery
    def self.call(...)
      new(...).call
    end

    def initialize(scope: Borrower.all, search: nil)
      @scope = scope
      @search = search.to_s.squish
    end

    def call
      return ordered_scope if search.blank?

      normalized_phone_query.present? ? phone_matches : name_matches
    end

    private
      attr_reader :scope, :search

      def ordered_scope
        scope.order(created_at: :desc, id: :desc)
      end

      def normalized_phone_query
        @normalized_phone_query ||= Borrower.normalize_phone_number(search)
      end

      def phone_matches
        ordered_scope.where(phone_number_normalized: normalized_phone_query)
      end

      def name_matches
        ordered_scope.where("full_name ILIKE ?", "%#{Borrower.sanitize_sql_like(search)}%")
      end
  end
end
