class LoanApplicationsController < ApplicationController
  before_action :set_loan_application, only: %i[show update]

  def index
    @search_query = params[:q].to_s.squish
    @status_filter = normalized_status_filter
    @loan_applications = LoanApplications::FilteredListQuery.call(
      status: @status_filter,
      search: @search_query
    )
    @has_applications = LoanApplication.exists?
  end

  def create
    borrower = Borrower.find(params[:borrower_id])
    result = LoanApplications::Create.call(borrower:)

    if result.success?
      redirect_to loan_application_path(result.loan_application), notice: "Application started successfully."
    else
      redirect_to borrower_path(borrower), alert: result.eligibility.next_step_message
    end
  end

  def show
    LoanApplications::InitializeReviewWorkflow.call(loan_application: @loan_application)
    @loan_application = LoanApplication.includes(:borrower, :review_steps).find(@loan_application.id)
    load_borrower_history
  end

  def update
    result = LoanApplications::UpdateDetails.call(
      loan_application: @loan_application,
      attributes: loan_application_params
    )

    if result.success?
      redirect_to loan_application_redirect_path, notice: "Application details saved successfully."
    elsif result.locked?
      redirect_to loan_application_redirect_path, alert: @loan_application.errors.full_messages.to_sentence
    else
      load_borrower_history
      render :show, status: :unprocessable_content
    end
  end

  private
    def set_loan_application
      @loan_application = LoanApplication.includes(:borrower).find(params[:id])
    end

    def loan_application_params
      params.require(:loan_application).permit(
        :requested_amount,
        :requested_tenure_in_months,
        :requested_repayment_frequency,
        :proposed_interest_mode,
        :request_notes
      )
    end

    def load_borrower_history
      @borrower_history = Borrowers::HistoryQuery.call(id: @loan_application.borrower_id)
      @borrower_history_records = @borrower_history.linked_records.reject do |record|
        record.type == "application" && record.identifier == @loan_application.application_number
      end
    end

    def normalized_status_filter
      candidate = params[:status].to_s.squish.downcase.presence
      candidate if LoanApplication::STATUSES.include?(candidate)
    end

    def loan_application_redirect_path
      if params[:from].present?
        loan_application_path(@loan_application, from: params[:from])
      else
        loan_application_path(@loan_application)
      end
    end
end
