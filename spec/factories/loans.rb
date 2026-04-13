FactoryBot.define do
  factory :loan do
    association :borrower
    loan_application { nil }
    sequence(:loan_number) { |n| "LOAN-#{n.to_s.rjust(4, '0')}" }
    status { "active" }
  end
end
