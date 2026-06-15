# frozen_string_literal: true

FactoryBot.define do
  factory :cc_recipient do
    association :document
    party { create(:contact, entity: document.entity) }
  end
end
