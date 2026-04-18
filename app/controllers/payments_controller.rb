class PaymentsController < ApplicationController
  before_action :set_payment, only: :show

  def index
    @search_query = params[:q].to_s.squish
    @status_filter = normalized_status_filter
    @view_filter = normalized_view_filter
    @due_window_filter = normalized_due_window_filter
    @payments = Payments::FilteredListQuery.call(
      status: @status_filter,
      search: @search_query,
      view: @view_filter,
      due_window: @due_window_filter
    )
    @has_payments = Payment.exists?
  end

  def show
  end

  private
    def set_payment
      @payment = Payment.includes(loan: :borrower).find(params[:id])
    end

    def normalized_status_filter
      candidate = params[:status].to_s.squish.downcase.presence
      candidate if Payment.aasm.states.map { |state| state.name.to_s }.include?(candidate)
    end

    def normalized_view_filter
      candidate = params[:view].to_s.squish.downcase.presence
      candidate if %w[upcoming overdue completed].include?(candidate)
    end

    def normalized_due_window_filter
      candidate = params[:due_window].to_s.squish.downcase.presence
      candidate if %w[overdue_by_any today this_week next_7_days this_month].include?(candidate)
    end
end
