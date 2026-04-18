module Payments
  class FilteredListQuery < ApplicationQuery
    VIEW_TO_STATUS = {
      "upcoming" => "pending",
      "overdue" => "overdue",
      "completed" => "completed"
    }.freeze

    DUE_WINDOWS = %w[overdue_by_any today this_week next_7_days this_month].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(scope: Payment.all, status: nil, search: nil, view: nil, due_window: nil)
      @scope = scope
      @view = normalized_view(view)
      @status = normalized_status(status) || view_to_status(@view)
      @search = search.to_s.squish
      @due_window = normalized_due_window(due_window)
    end

    def call
      relation = ordered_scope
      relation = relation.where(status:) if status.present?
      relation = apply_due_window(relation) if apply_due_window?
      relation = search_matches(relation) if search.present?
      relation
    end

    private
      attr_reader :scope, :status, :view, :search, :due_window

      def apply_due_window?
        return false if due_window.blank?

        due_window == "overdue_by_any" || status == "pending"
      end

      def ordered_scope
        scope.includes(loan: :borrower).order(:due_date, :installment_number, :created_at, :id)
      end

      def normalized_status(value)
        candidate = value.to_s.squish.downcase.presence
        candidate if Payment.aasm.states.map { |state| state.name.to_s }.include?(candidate)
      end

      def normalized_view(value)
        candidate = value.to_s.squish.downcase.presence
        candidate if VIEW_TO_STATUS.key?(candidate)
      end

      def normalized_due_window(value)
        candidate = value.to_s.squish.downcase.presence
        candidate if DUE_WINDOWS.include?(candidate)
      end

      def view_to_status(view_value)
        VIEW_TO_STATUS[view_value]
      end

      def apply_due_window(relation)
        today = Date.current

        range = case due_window
        when "overdue_by_any"
          ...today
        when "today"
          today..today
        when "this_week"
          today.beginning_of_week..today.end_of_week
        when "next_7_days"
          today..(today + 7.days)
        when "this_month"
          today.beginning_of_month..today.end_of_month
        end

        relation.where(due_date: range)
      end

      def search_matches(relation)
        query = "%#{Payment.sanitize_sql_like(search)}%"

        relation.joins(loan: :borrower).where(
          "loans.loan_number ILIKE :query OR borrowers.full_name ILIKE :query",
          query:
        )
      end
  end
end
