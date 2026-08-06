# frozen_string_literal: true

FactoryBot.define do
  factory :document_template do
    association :entity
    association :created_by, factory: :user
    sequence(:name) { |n| "Document template #{n}" }
    subject_template { "VAT exemption request - {{supplier}}" }
    body_template { "Please find enclosed our VAT exemption request for {{supplier}}, amount {{amount}}." }
  end
end
