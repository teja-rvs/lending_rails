class LoanApplicationsController < ApplicationController
  before_action :set_loan_application, only: %i[show update]

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
  end

  def update
    result = LoanApplications::UpdateDetails.call(
      loan_application: @loan_application,
      attributes: loan_application_params
    )

    if result.success?
      redirect_to loan_application_path(@loan_application), notice: "Application details saved successfully."
    elsif result.locked?
      redirect_to loan_application_path(@loan_application), alert: @loan_application.errors.full_messages.to_sentence
    else
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
end
