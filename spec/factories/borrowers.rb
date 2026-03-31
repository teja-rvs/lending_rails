FactoryBot.define do
  factory :borrower do
    sequence(:full_name) { |n| "Borrower #{n}" }
    sequence(:phone_number) { |n| "+9198765#{n.to_s.rjust(5, '0')}" }
  end
end
