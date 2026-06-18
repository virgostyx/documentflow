# frozen_string_literal: true

FactoryBot.define do
  factory :department do
    association :entity
    sequence(:name) { |n| "Department #{n}" }
    is_default { false }

    trait :default do
      is_default { true }
      name { "General" }
    end
  end
end
