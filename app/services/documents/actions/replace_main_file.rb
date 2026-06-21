# frozen_string_literal: true

module Documents
  module Actions
    class ReplaceMainFile < ApplicationAction
      expects :document, :document_file_version, :current_user

      executed do |ctx|
        document = ctx.document
        document.main_file.purge if document.main_file.attached?
        document.main_file.attach(ctx.document_file_version.file.blob)

        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:audit_action] = "check_in"
        ctx[:audit_changes] = { version_number: ctx.document_file_version.version_number }
      end
    end
  end
end
