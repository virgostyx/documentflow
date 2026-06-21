# frozen_string_literal: true

module Documents
  module Actions
    class CreateFileVersion < ApplicationAction
      expects :document, :current_user, :file
      promises :document_file_version

      executed do |ctx|
        if ctx.file.blank?
          next fail_with!(ctx, "Please select a file to check in", :validation_error)
        end

        version = ctx.document.document_file_versions.build(
          user: ctx.current_user,
          version_number: DocumentFileVersion.next_version_number(ctx.document),
          comment: ctx[:comment]
        )
        version.file.attach(ctx.file)

        unless version.save
          next fail_with!(ctx, version.errors.full_messages.to_sentence, :validation_error)
        end

        ctx.document_file_version = version
      end
    end
  end
end
