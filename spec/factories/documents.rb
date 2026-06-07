# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    association :entity
    association :created_by, factory: :user
    sender { create(:contact, entity: entity) }
    addressee { create(:contact, entity: entity) }
    subject { "Contrat de prestation" }
    document_date { Date.current }
    status { "draft" }

    trait :in_progress do
      status { "in_progress" }
    end

    trait :signed do
      status { "signed" }
    end

    trait :finalized do
      status { "finalized" }
      is_frozen { true }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
