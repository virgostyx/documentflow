# frozen_string_literal: true

FactoryBot.define do
  factory :email_template_field do
    association :email_template
    sequence(:tag_name) { |n| "field_#{n}" }
    label { "Field" }
    field_type { "text" }
    required { true }
    sequence(:position)
  end
end
