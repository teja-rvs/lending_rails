require "rails_helper"

RSpec.describe "Derived state integrity" do
  describe "full lifecycle derivation" do
    it "derives correct loan states through the complete lifecycle" do
      borrower = create(:borrower, full_name: "Asha Patel", phone_number: "+91 98765 43210")
      loan = create(:loan, :active, :with_details, borrower: borrower, disbursement_date: Date.current - 90.days)

      payment_1 = create(:payment, :pending, loan: loan, installment_number: 1,
        due_date: Date.current - 30.days)
      payment_2 = create(:payment, :pending, loan: loan, installment_number: 2,
        due_date: Date.current - 10.days)
      payment_3 = create(:payment, :pending, loan: loan, installment_number: 3,
        due_date: Date.current + 30.days)

      result = Loans::RefreshStatus.call(loan: loan)

      expect(result).to be_success
      expect(loan.reload).to be_overdue
      expect(payment_1.reload).to be_overdue
      expect(payment_2.reload).to be_overdue
      expect(payment_3.reload).to be_pending

      expect(payment_1.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      expect(payment_2.late_fee_cents).to eq(Payments::LateFeePolicy.flat_fee_cents)
      expect(payment_3.late_fee_cents).to eq(0)

      Payments::MarkCompleted.call(
        payment: payment_1,
        payment_date: Date.current,
        payment_mode: "cash"
      )
      Payments::MarkCompleted.call(
        payment: payment_2,
        payment_date: Date.current,
        payment_mode: "cash"
      )

      Loans::RefreshStatus.call(loan: loan.reload)
      expect(loan.reload).to be_active

      Payments::MarkCompleted.call(
        payment: payment_3.reload,
        payment_date: Date.current,
        payment_mode: "cash"
      )

      Loans::RefreshStatus.call(loan: loan.reload)
      expect(loan.reload).to be_closed
    end
  end

  describe "dashboard query consistency" do
    it "returns counts consistent with persisted derived states after RefreshStatus" do
      borrower = create(:borrower)

      active_loan = create(:loan, :active, :with_details, borrower: borrower, disbursement_date: Date.current - 60.days)
      create(:payment, :pending, loan: active_loan, installment_number: 1,
        due_date: Date.current - 5.days)

      closeable_loan = create(:loan, :active, :with_details, disbursement_date: Date.current - 90.days)
      create(:payment, :completed, loan: closeable_loan, installment_number: 1,
        due_date: Date.current - 30.days)

      Loans::RefreshStatus.call(loan: active_loan)
      Loans::RefreshStatus.call(loan: closeable_loan)

      expect(active_loan.reload).to be_overdue
      expect(closeable_loan.reload).to be_closed

      expect(Dashboard::ActiveLoansQuery.call).to eq(1)
      expect(Dashboard::OverduePaymentsQuery.call).to eq(1)

      portfolio = Dashboard::PortfolioSummaryQuery.call
      expect(portfolio.closed_loans_count).to eq(1)
    end
  end
end
