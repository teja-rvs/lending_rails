module Dashboard
  class UpcomingPaymentsQuery < ApplicationQuery
    def self.call(...)
      new(...).call
    end

    def call
      Payment.where(status: "pending", due_date: Date.current..(Date.current + 7.days)).count
    end
  end
end
