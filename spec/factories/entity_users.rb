# frozen_string_literal: true

FactoryBot.define do
  factory :entity_user do
    association :entity
    association :user
    invited_email { user.email }
    role { "member" }
    status { "active" }

    trait :owner do
      role { "owner" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :guest do
      role { "guest" }
    end

    trait :pending do
      status { "pending" }
    end

    trait :suspended do
      status { "suspended" }
    end
  end
end
