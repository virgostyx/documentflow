# frozen_string_literal: true

FactoryBot.define do
  factory :folder do
    entity { create(:entity) }
    department { create(:department, entity: entity) }
    sequence(:name) { |n| "Folder #{n}" }

    trait :subfolder do
      parent { create(:folder, entity: entity, department: department) }
    end
  end
end
