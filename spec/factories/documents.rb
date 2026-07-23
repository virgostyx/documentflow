# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    association :entity
    association :created_by, factory: :user
    department { create(:department, entity: entity) }
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
      is_frozen { true }
    end

    trait :finalized do
      status { "finalized" }
      is_frozen { true }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :expecting_response do
      expects_response { true }
    end

    trait :incoming do
      direction { "incoming" }
      addressee { lead_user }

      lead_user do
        user = create(:user)
        create(:entity_user, entity: entity, user: user, status: "active")
        user
      end
    end

    trait :with_workflow do
      after(:create) do |document|
        document.main_file.attach(io: StringIO.new("content"), filename: "main.pdf", content_type: "application/pdf")

        create(:workflow_step, :red,  document: document, order: 1, actor: document.created_by)
        create(:workflow_step, :visa, document: document, order: 2, actor: create(:user))
        create(:workflow_step, :sign, document: document, order: 3, actor: create(:user))
        create(:workflow_step, :exp,  document: document, order: 4, actor: create(:user))
      end
    end
  end
end
