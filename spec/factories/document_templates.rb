# frozen_string_literal: true

FactoryBot.define do
  factory :document_template do
    association :entity
    association :created_by, factory: :user
    sequence(:name) { |n| "Document template #{n}" }
    subject_template { "VAT exemption request - {{supplier}}" }

    after(:build) do |document_template|
      next if document_template.source_file.attached?

      document_template.source_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/document_template.docx")),
        filename: "template.docx", content_type: DocumentTemplate::DOCX_CONTENT_TYPE
      )
    end
  end
end
