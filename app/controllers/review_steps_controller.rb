class ReviewStepsController < ApplicationController
  before_action :set_loan_application

  def approve
    handle_result(ReviewSteps::Approve.call(loan_application: @loan_application, review_step_id: params[:id]))
  end

  def request_details
    handle_result(ReviewSteps::RequestDetails.call(loan_application: @loan_application, review_step_id: params[:id]))
  end

  private
    def set_loan_application
      @loan_application = LoanApplication.find(params[:loan_application_id])
    end

    def handle_result(result)
      if result.success?
        redirect_to loan_application_path(@loan_application), notice: result.message
      else
        redirect_to loan_application_path(@loan_application), alert: result.error
      end
    end
end
