# frozen_string_literal: true

module Documents
  module Actions
    class CreateFileVersions < ApplicationAction
      expects :document, :current_user
      promises :document_file_versions

      executed do |ctx|
        main_file = ctx[:main_file]
        annex_files = ctx[:annex_files] || {}

        if main_file.blank? && annex_files.blank?
          next fail_with!(ctx, "Please select at least one file to check in", :validation_error)
        end

        version_number = DocumentFileVersion.next_version_number(ctx.document)
        versions = []
        error_message = nil

        if main_file.present?
          version = ctx.document.document_file_versions.build(
            user: ctx.current_user, version_number: version_number, comment: ctx[:comment]
          )
          version.file.attach(main_file)

          if version.save
            versions << version
          else
            error_message = version.errors.full_messages.to_sentence
          end
        end

        if error_message.nil?
          annex_files.each do |annex_id, file|
            version = ctx.document.document_file_versions.build(
              user: ctx.current_user, annex: ctx.document.annexes.find(annex_id),
              version_number: version_number, comment: ctx[:comment]
            )
            version.file.attach(file)

            if version.save
              versions << version
            else
              error_message = version.errors.full_messages.to_sentence
              break
            end
          end
        end

        next fail_with!(ctx, error_message, :validation_error) if error_message

        ctx.document_file_versions = versions
        ctx[:user] = ctx.current_user
        ctx[:auditable] = ctx.document
        ctx[:audit_action] = "check_in"
        ctx[:audit_changes] = { version_number: version_number }
      end
    end
  end
end
