FactoryBot.define do
  factory :loan_application do
    association :borrower
    sequence(:application_number) { |n| "APP-#{n.to_s.rjust(4, '0')}" }
    status { "open" }
    borrower_full_name_snapshot { borrower.full_name }
    borrower_phone_number_snapshot { borrower.phone_number_normalized }

    trait :in_progress do
      status { "in progress" }
    end

    trait :approved do
      status { "approved" }
    end

    trait :rejected do
      status { "rejected" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :with_details do
      requested_amount { 25_000 }
      requested_tenure_in_months { 12 }
      requested_repayment_frequency { "monthly" }
      proposed_interest_mode { "rate" }
      request_notes { "Borrower expects steady monthly installments." }
    end
  end
end
