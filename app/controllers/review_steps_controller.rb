class ReviewStepsController < ApplicationController
  before_action :set_loan_application

  def approve
    handle_result(ReviewSteps::Approve.call(loan_application: @loan_application, review_step_id: params[:id]))
  end

  def reject
    handle_result(
      ReviewSteps::Reject.call(
        loan_application: @loan_application,
        review_step_id: params[:id],
        rejection_note: params[:rejection_note]
      )
    )
  end

  private
    def set_loan_application
      @loan_application = LoanApplication.find(params[:loan_application_id])
    end

    def handle_result(result)
      if result.success?
        redirect_to loan_application_redirect_path, notice: result.message
      else
        redirect_to loan_application_redirect_path, alert: result.error
      end
    end

    def loan_application_redirect_path
      if params[:from].present?
        loan_application_path(@loan_application, from: params[:from])
      else
        loan_application_path(@loan_application)
      end
    end
end
