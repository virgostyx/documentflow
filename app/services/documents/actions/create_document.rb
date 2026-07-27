# frozen_string_literal: true

module Documents
  module Actions
    class CreateDocument < ApplicationAction
      expects :entity, :current_user, :document_params
      promises :document

      executed do |ctx|
        document = Document.new(
          ctx.document_params.merge(entity: ctx.entity, created_by: ctx.current_user)
        )

        if document.save
          ctx.document = document
          ctx[:user] = ctx.current_user
          ctx[:auditable] = document
          ctx[:action] = "create"
          ctx[:audit_changes] = {
            subject: document.subject,
            reference_number: document.reference_number,
            temporary_number: document.temporary_number,
            expects_response: document.expects_response
          }
        else
          fail_with!(ctx, document.errors.full_messages.to_sentence, :validation_error)
        end
      end
    end
  end
end
