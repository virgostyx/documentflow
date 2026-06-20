# frozen_string_literal: true

module IncomingMails
  module Actions
    class RegisterIncomingMail < ApplicationAction
      expects :entity, :current_user, :document_params
      promises :document

      executed do |ctx|
        document = Document.new(
          ctx.document_params.merge(
            entity: ctx.entity,
            created_by: ctx.current_user,
            direction: "incoming",
            addressee_type: "User",
            addressee_id: ctx.document_params[:lead_user_id]
          )
        )

        if document.save
          ctx.document = document
          ctx[:user] = ctx.current_user
          ctx[:auditable] = document
          ctx[:action] = "register"
          ctx[:audit_changes] = { subject: document.subject, reference_number: document.reference_number, lead_user_id: document.lead_user_id }
        else
          fail_with!(ctx, document.errors.full_messages.to_sentence, :validation_error)
        end
      end
    end
  end
end
