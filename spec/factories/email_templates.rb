# frozen_string_literal: true

FactoryBot.define do
  factory :email_template do
    association :entity
    association :created_by, factory: :user
    sequence(:name) { |n| "Email template #{n}" }
    body_template { "Dear {{recipient_name}}, please find attached documents for {{reference}}. Deadline: {{deadline}}." }
  end
end
