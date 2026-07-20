# frozen_string_literal: true

FactoryBot.define do
  factory :department do
    association :entity
    sequence(:name) { |n| "Department #{n}" }
    is_default { false }

    trait :default do
      is_default { true }
      name { "General" }
    end

    trait :with_logo do
      after(:build) do |department|
        department.logo.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/logo.png")),
          filename: "logo.png",
          content_type: "image/png"
        )
      end
    end
  end
end
