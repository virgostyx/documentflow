# frozen_string_literal: true

module EmailArchive
  module Actions
    # Builds the Document already in its final state — the email was already
    # sent outside DocumentFlow, so there's nothing left to approve: no
    # workflow_steps, no AASM event, straight to status: "finalized".
    class CreateArchivedDocument < ApplicationAction
      expects :mail, :entity, :department, :sender_user, :addressee_contact
      promises :document

      executed do |ctx|
        document = Document.new(
          entity: ctx.entity,
          department: ctx.department,
          created_by: ctx.sender_user,
          sender: ctx.sender_user,
          addressee: ctx.addressee_contact,
          direction: "outgoing",
          status: "finalized",
          is_frozen: true,
          archived_from_email: true,
          subject: ctx.mail.subject.presence || "(no subject)",
          document_date: (ctx.mail.date || Time.current).to_date
        )

        if document.save
          ctx.document = document
          ctx[:user] = ctx.sender_user
          ctx[:auditable] = document
          ctx[:action] = "archive_from_email"
          ctx[:audit_changes] = { subject: document.subject, reference_number: document.reference_number, addressee: document.addressee_token }
        else
          fail_with!(ctx, document.errors.full_messages.to_sentence, :validation_error)
        end
      end
    end
  end
end
