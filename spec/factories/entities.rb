# frozen_string_literal: true

FactoryBot.define do
  factory :entity do
    sequence(:name) { |n| "Entity #{n}" }
    status { "active" }

    trait :suspended do
      status { "suspended" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
