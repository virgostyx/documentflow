FactoryBot.define do
  factory :webauthn_credential do
    association :user
    sequence(:external_id) { |n| "external-id-#{n}" }
    sequence(:nickname) { |n| "Security key #{n}" }
    public_key { "dummy-public-key" }
    sign_count { 0 }
  end
end
