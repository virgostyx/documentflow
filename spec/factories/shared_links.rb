# frozen_string_literal: true

FactoryBot.define do
  factory :shared_link do
    association :document

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
