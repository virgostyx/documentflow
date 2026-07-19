# frozen_string_literal: true

module Documents
  module Actions
    class ReplaceAnnexFiles < ApplicationAction
      expects :document, :document_file_versions

      executed do |ctx|
        annex_versions = ctx.document_file_versions.select { |version| version.annex_id.present? }
        next if annex_versions.empty?

        annex_versions.each do |version|
          annex = version.annex
          annex.file.purge if annex.file.attached?
          annex.file.attach(version.file.blob)
        end
      end
    end
  end
end
