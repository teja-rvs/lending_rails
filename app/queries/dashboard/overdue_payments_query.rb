module Dashboard
  class OverduePaymentsQuery < ApplicationQuery
    def self.call(...)
      new(...).call
    end

    def call
      Payment.where(status: "overdue").count
    end
  end
end
