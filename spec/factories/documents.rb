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

    trait :with_workflow do
      after(:create) do |document|
        create(:workflow_step, :red,  document: document, order: 1, actor: document.created_by)
        create(:workflow_step, :visa, document: document, order: 2, actor: create(:user))
        create(:workflow_step, :sign, document: document, order: 3, actor: create(:user))
        create(:workflow_step, :exp,  document: document, order: 4, actor: create(:user))
      end
    end
  end
end
