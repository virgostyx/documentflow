# frozen_string_literal: true

module Workflow
  module Actions
    # Records, per external recipient, whether the EXP actor chose to dispatch
    # this document as an email attachment instead of a shared link. Read later
    # by NotificationMailer when AddresseeNotificationJob/CcNotificationJob run.
    class SetDispatchPreference < ApplicationAction
      expects :step, :document

      executed do |ctx|
        next unless ctx.step.exp?

        document = ctx.document

        if document.addressee.external?
          document.update_column(
            :addressee_dispatch_as_attachment,
            ActiveModel::Type::Boolean.new.cast(ctx[:addressee_dispatch_as_attachment]) || false
          )
        end

        attachment_cc_ids = Array(ctx[:cc_dispatch_as_attachment_ids]).map(&:to_i)
        document.cc_recipients.each do |cc_recipient|
          next unless cc_recipient.party.external?

          cc_recipient.update_column(:dispatch_as_attachment, attachment_cc_ids.include?(cc_recipient.id))
        end

        document.update_column(
          :include_attachment_note,
          ActiveModel::Type::Boolean.new.cast(ctx[:include_attachment_note]) || false
        )
      end
    end
  end
end
