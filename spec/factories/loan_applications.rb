FactoryBot.define do
  factory :loan_application do
    association :borrower
    sequence(:application_number) { |n| "APP-#{n.to_s.rjust(4, '0')}" }
    status { "open" }
  end
end
