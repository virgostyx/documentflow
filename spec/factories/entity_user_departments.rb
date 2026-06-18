# frozen_string_literal: true

FactoryBot.define do
  factory :entity_user_department do
    association :entity_user
    department { create(:department, entity: entity_user.entity) }
    primary { false }

    trait :primary do
      primary { true }
    end
  end
end
