class LoansController < ApplicationController
  before_action :set_loan, only: %i[show update begin_documentation]

  def index
    @search_query = params[:q].to_s.squish
    @status_filter = normalized_status_filter
    @loans = Loans::FilteredListQuery.call(status: @status_filter, search: @search_query)
    @has_loans = Loan.exists?
  end

  def show
  end

  def update
    result = Loans::UpdateDetails.call(loan: @loan, attributes: loan_params)

    if result.success?
      redirect_to loan_redirect_path, notice: "Loan details saved successfully."
    elsif result.locked?
      redirect_to loan_redirect_path, alert: @loan.errors.full_messages.to_sentence
    elsif result.blocked?
      redirect_to loan_redirect_path, alert: result.error
    else
      render :show, status: :unprocessable_content
    end
  end

  def begin_documentation
    @loan.with_lock do
      if @loan.may_begin_documentation?
        @loan.begin_documentation!
        redirect_to loan_redirect_path, notice: "Documentation stage started for #{@loan.loan_number}."
      else
        redirect_to loan_redirect_path, alert: "This loan cannot begin documentation from its current state."
      end
    end
  end

  private
    def set_loan
      @loan = Loan.includes(:borrower, :loan_application).find(params[:id])
    end

    def loan_params
      params.require(:loan).permit(
        :principal_amount,
        :tenure_in_months,
        :repayment_frequency,
        :interest_mode,
        :interest_rate,
        :total_interest_amount,
        :notes
      )
    end

    def normalized_status_filter
      candidate = params[:status].to_s.squish.downcase.presence
      candidate if Loan.aasm.states.map { |state| state.name.to_s }.include?(candidate)
    end

    def loan_redirect_path
      if params[:from].present?
        loan_path(@loan, from: params[:from])
      else
        loan_path(@loan)
      end
    end
end
