# frozen_string_literal: true

FactoryBot.define do
  factory :document_dismissal do
    association :document
    association :user
    tab { "waiting" }
  end
end
