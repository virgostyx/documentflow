# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_step do
    association :document
    role { "RED" }
    order { 1 }
    status { "pending" }

    trait :red do
      role { "RED" }
    end

    trait :visa do
      role { "VISA" }
    end

    trait :sign do
      role { "SIGN" }
    end

    trait :exp do
      role { "EXP" }
    end

    trait :approved do
      status { "approved" }
    end

    trait :rejected do
      status { "rejected" }
    end

    trait :skipped do
      status { "skipped" }
    end

    trait :parallel do
      is_parallel { true }
      parallel_group { 1 }
    end
  end
end
