module Dashboard
  class PortfolioSummaryQuery < ApplicationQuery
    Result = Struct.new(:closed_loans_count, :total_disbursed_cents, :total_repayment_cents, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def call
      Result.new(
        closed_loans_count: Loan.where(status: "closed").count,
        total_disbursed_cents: Invoice.disbursement.sum(:amount_cents),
        total_repayment_cents: Invoice.payment.sum(:amount_cents)
      )
    end
  end
end
