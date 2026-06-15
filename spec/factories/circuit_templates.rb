# frozen_string_literal: true

FactoryBot.define do
  factory :circuit_template do
    association :entity
    sequence(:name) { |n| "Circuit template #{n}" }
  end
end
