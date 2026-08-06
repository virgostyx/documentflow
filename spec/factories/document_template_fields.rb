# frozen_string_literal: true

FactoryBot.define do
  factory :document_template_field do
    association :document_template
    sequence(:tag_name) { |n| "field_#{n}" }
    label { "Field" }
    field_type { "text" }
    required { true }
    sequence(:position)
  end
end
