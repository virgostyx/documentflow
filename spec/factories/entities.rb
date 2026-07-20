# frozen_string_literal: true

FactoryBot.define do
  factory :entity do
    sequence(:name) { |n| "Entity #{n}" }
    status { "active" }

    trait :suspended do
      status { "suspended" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :with_logo do
      acronym { "ACR" }

      after(:build) do |entity|
        entity.logo.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/logo.png")),
          filename: "logo.png",
          content_type: "image/png"
        )
      end
    end
  end
end
