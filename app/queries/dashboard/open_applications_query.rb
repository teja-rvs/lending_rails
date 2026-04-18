module Dashboard
  class OpenApplicationsQuery < ApplicationQuery
    def self.call(...)
      new(...).call
    end

    def call
      LoanApplication.where(status: [ "open", "in progress" ]).count
    end
  end
end
