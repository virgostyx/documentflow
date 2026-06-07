# frozen_string_literal: true

FactoryBot.define do
  factory :contact do
    association :entity
    first_name { "Jean" }
    last_name  { "Dupont" }
    sequence(:email) { |n| "contact#{n}@example.com" }
    company { "Acme Corp" }
    phone { "+32 2 123 45 67" }
  end
end
