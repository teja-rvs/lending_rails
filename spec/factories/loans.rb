FactoryBot.define do
  factory :loan do
    association :borrower
    loan_application { nil }
    sequence(:loan_number) { |n| "LOAN-#{n.to_s.rjust(4, '0')}" }
    status { "created" }
    borrower_full_name_snapshot { borrower.full_name }
    borrower_phone_number_snapshot { borrower.phone_number_normalized }
    principal_amount { nil }
    tenure_in_months { nil }
    repayment_frequency { nil }
    interest_mode { nil }
    interest_rate { nil }
    total_interest_amount { nil }
    disbursement_date { nil }
    notes { nil }

    trait :created do
      status { "created" }
    end

    trait :documentation_in_progress do
      status { "documentation_in_progress" }
    end

    trait :ready_for_disbursement do
      status { "ready_for_disbursement" }
    end

    trait :active do
      status { "active" }
      disbursement_date { Date.current }
    end

    trait :overdue do
      status { "overdue" }
    end

    trait :closed do
      status { "closed" }
    end

    trait :with_details do
      principal_amount { 45_000 }
      tenure_in_months { 12 }
      repayment_frequency { "monthly" }
      interest_mode { "rate" }
      interest_rate { BigDecimal("12.5000") }
      total_interest_amount { nil }
      notes { "Borrower confirmed monthly repayment preference." }
    end

    trait :with_total_interest_details do
      principal_amount { 45_000 }
      tenure_in_months { 12 }
      repayment_frequency { "monthly" }
      interest_mode { "total_interest_amount" }
      interest_rate { nil }
      total_interest_amount { 8_000 }
      notes { "Borrower agreed to a fixed total interest amount." }
    end
  end
end
