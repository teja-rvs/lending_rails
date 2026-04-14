FactoryBot.define do
  factory :loan do
    association :borrower
    loan_application { nil }
    sequence(:loan_number) { |n| "LOAN-#{n.to_s.rjust(4, '0')}" }
    status { "created" }
    borrower_full_name_snapshot { borrower.full_name }
    borrower_phone_number_snapshot { borrower.phone_number_normalized }

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
    end

    trait :overdue do
      status { "overdue" }
    end

    trait :closed do
      status { "closed" }
    end
  end
end
