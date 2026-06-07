FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "password123" }
    super_admin { false }

    trait :super_admin do
      super_admin { true }
    end
  end
end
