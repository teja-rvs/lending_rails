class LoanApplicationsController < ApplicationController
  def show
    @loan_application = LoanApplication.includes(:borrower).find(params[:id])
  end
end
