FactoryBot.define do
  factory :invoice do
    association :loan
    sequence(:invoice_number) { |n| "INV-#{n.to_s.rjust(4, '0')}" }
    invoice_type { "disbursement" }
    amount_cents { loan.principal_amount_cents || 4_500_000 }
    currency { "INR" }
    issued_on { Date.current }
    notes { nil }

    trait :disbursement do
      invoice_type { "disbursement" }
    end
  end
end
