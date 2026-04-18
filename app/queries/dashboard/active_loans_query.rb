module Dashboard
  class ActiveLoansQuery < ApplicationQuery
    def self.call(...)
      new(...).call
    end

    def call
      Loan.where(status: %w[active overdue]).count
    end
  end
end
