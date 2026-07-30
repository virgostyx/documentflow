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

    # Owner/admin roles make two-factor authentication mandatory for the
    # user (see User#two_factor_required?), which would otherwise redirect
    # every request in specs that aren't testing that onboarding flow itself.
    after(:create) do |entity_user|
      user = entity_user.user
      next unless user && entity_user.reload.active? && user.reload.two_factor_required?
      next if user.otp_required_for_login?

      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)
    end
  end
end
