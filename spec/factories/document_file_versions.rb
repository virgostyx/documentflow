# frozen_string_literal: true

FactoryBot.define do
  factory :document_file_version do
    association :document
    association :user
    version_number { 1 }

    after(:build) do |version|
      version.file.attach(io: StringIO.new("content"), filename: "version.pdf", content_type: "application/pdf") unless version.file.attached?
    end
  end
end
