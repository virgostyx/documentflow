# frozen_string_literal: true

FactoryBot.define do
  factory :circuit_template_step do
    association :circuit_template
    role { "RED" }
    order { 1 }

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

    trait :parallel do
      is_parallel { true }
      parallel_group { 1 }
    end
  end
end
