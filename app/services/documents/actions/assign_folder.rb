# frozen_string_literal: true

module Documents
  module Actions
    class AssignFolder < ApplicationAction
      expects :document, :current_user
      expects :folder, default: nil

      executed do |ctx|
        folder = ctx.folder
        document = ctx.document

        if folder.present? && !Pundit.policy_scope(ctx.current_user, Folder).exists?(id: folder.id, department_id: document.department_id)
          next fail_with!(ctx, "You do not have access to that folder")
        end

        if document.update(folder: folder)
          ctx[:user] = ctx.current_user
          ctx[:auditable] = document
          ctx[:action] = "file"
          ctx[:audit_changes] = { folder_id: document.folder_id }

          succeed_with!(ctx, folder ? "Document filed into #{folder.name}." : "Document removed from folder.")
        else
          fail_with!(ctx, document.errors.full_messages.to_sentence)
        end
      end
    end
  end
end
