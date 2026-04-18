# Applied exactly once per installment, at the moment it first becomes overdue. FR52.
module Payments
  module LateFeePolicy
    MVP_FLAT_LATE_FEE_CENTS = 25_00

    def self.flat_fee_cents
      MVP_FLAT_LATE_FEE_CENTS
    end
  end
end
