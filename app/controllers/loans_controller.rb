class LoansController < ApplicationController
  def show
    @loan = Loan.includes(:borrower, :loan_application).find(params[:id])
  end
end
