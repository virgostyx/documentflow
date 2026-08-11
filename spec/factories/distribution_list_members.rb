# frozen_string_literal: true

FactoryBot.define do
  factory :distribution_list_member do
    association :distribution_list
    party { create(:contact) }
    sequence(:position) { |n| n }
  end
end
