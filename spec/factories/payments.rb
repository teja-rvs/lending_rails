FactoryBot.define do
  factory :payment do
    association :loan, factory: [ :loan, :active, :with_details ]
    sequence(:installment_number) { |n| n }
    due_date { (loan.disbursement_date || Date.current) + installment_number.months }
    principal_amount_cents { 375_000 }
    interest_amount_cents { 46_875 }
    total_amount_cents { principal_amount_cents + interest_amount_cents }
    status { "pending" }
    payment_date { nil }
    payment_mode { nil }
    late_fee_cents { 0 }
    completed_at { nil }
    notes { nil }

    trait :pending do
      status { "pending" }
      payment_date { nil }
      completed_at { nil }
    end

    trait :completed do
      status { "completed" }
      payment_date { Date.current }
      payment_mode { "cash" }
      completed_at { Time.current }
    end

    trait :overdue do
      status { "overdue" }
    end
  end
end
