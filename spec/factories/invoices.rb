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

    trait :payment do
      invoice_type { "payment" }
      association :payment, factory: %i[payment completed]
      loan { payment&.loan }
      amount_cents { payment&.total_amount_cents || 50_000 }
      issued_on { payment&.payment_date || Date.current }
    end
  end
end
