# frozen_string_literal: true

FactoryBot.define do
  factory :distribution_list do
    association :user
    sequence(:name) { |n| "Distribution list #{n}" }
  end
end
