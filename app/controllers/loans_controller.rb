class LoansController < ApplicationController
  before_action :set_loan, only: %i[show update begin_documentation complete_documentation attempt_disbursement disburse]

  def index
    @search_query = params[:q].to_s.squish
    @status_filter = normalized_status_filter
    @loans = Loans::FilteredListQuery.call(status: @status_filter, search: @search_query)
    @has_loans = Loan.exists?
  end

  def show
    set_disbursement_readiness
    @document_upload = @loan.document_uploads.build(uploaded_by: Current.user)
    @payments = @loan.payments.includes(:invoice).ordered
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
      set_disbursement_readiness
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

  def complete_documentation
    @loan.with_lock do
      if @loan.may_complete_documentation?
        @loan.complete_documentation!
        redirect_to loan_redirect_path, notice: "Documentation completed for #{@loan.loan_number}. Loan is now ready for disbursement."
      else
        redirect_to loan_redirect_path, alert: "This loan cannot complete documentation from its current state."
      end
    end
  end

  def attempt_disbursement
    @loan.with_lock do
      readiness = Loans::EvaluateDisbursementReadiness.call(loan: @loan)

      if readiness.ready_for_disbursement_action?
        redirect_to loan_redirect_path, notice: "Disbursement readiness confirmed for #{@loan.loan_number}."
      else
        redirect_to loan_redirect_path, alert: readiness.blocked_summary
      end
    end
  end

  def disburse
    result = Loans::Disburse.call(loan: @loan, disbursed_by: Current.user)

    if result.success?
      redirect_to loan_redirect_path, notice: "#{@loan.loan_number} has been disbursed. The loan is now active and repayment tracking begins."
    else
      redirect_to loan_redirect_path, alert: result.error
    end
  end

  private
    def set_loan
      @loan = Loan.includes(
        :borrower,
        :loan_application,
        :invoices,
        :payments,
        document_uploads: [
          :uploaded_by,
          :superseded_by,
          { file_attachment: :blob }
        ]
      ).find(params[:id])
    end

    def set_disbursement_readiness
      @disbursement_readiness = Loans::EvaluateDisbursementReadiness.call(loan: @loan)
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
