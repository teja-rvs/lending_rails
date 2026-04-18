class DashboardController < ApplicationController
  def show
    authorize :dashboard

    @overdue_payments_count = Dashboard::OverduePaymentsQuery.call
    @upcoming_payments_count = Dashboard::UpcomingPaymentsQuery.call
    @open_applications_count = Dashboard::OpenApplicationsQuery.call
    @active_loans_count = Dashboard::ActiveLoansQuery.call
    @portfolio = Dashboard::PortfolioSummaryQuery.call
  end
end
