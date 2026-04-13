FactoryBot.define do
  factory :review_step do
    association :loan_application
    step_key { "history_check" }
    position { 1 }
    status { "initialized" }

    trait :history_check do
      step_key { "history_check" }
      position { 1 }
    end

    trait :phone_screening do
      step_key { "phone_screening" }
      position { 2 }
    end

    trait :verification do
      step_key { "verification" }
      position { 3 }
    end
  end
end
