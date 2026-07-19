# frozen_string_literal: true

module Documents
  module Actions
    class ReplaceMainFile < ApplicationAction
      expects :document, :document_file_versions

      executed do |ctx|
        main_version = ctx.document_file_versions.find { |version| version.annex_id.nil? }
        next if main_version.nil?

        document = ctx.document
        document.main_file.purge if document.main_file.attached?
        document.main_file.attach(main_version.file.blob)
      end
    end
  end
end
