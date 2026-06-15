FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { "password123" }
    super_admin { false }

    trait :super_admin do
      super_admin { true }
    end
  end
end
