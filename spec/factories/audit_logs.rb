# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    association :user
    association :auditable, factory: :document

    action { "document_created" }
    change_data { {} }
    ip_address { "127.0.0.1" }
    user_agent { "Mozilla/5.0" }
  end
end
