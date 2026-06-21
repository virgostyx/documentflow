# frozen_string_literal: true

FactoryBot.define do
  factory :classification_node do
    entity { create(:entity) }
    sequence(:code) { |n| n.to_s }
    sequence(:name) { |n| "Classification #{n}" }

    trait :child do
      parent { create(:classification_node, entity: entity) }
      code { "#{parent.code}.1" }
    end
  end
end
