# frozen_string_literal: true

module Workflow
  module Actions
    # Persists the EXP actor's message, read later by NotificationMailer when
    # AddresseeNotificationJob/CcNotificationJob run. ValidateDispatchMessage
    # already guaranteed presence, so this only runs once that has passed.
    class SetDispatchMessage < ApplicationAction
      expects :step, :document

      executed do |ctx|
        next unless ctx.step.exp?

        ctx.document.update_columns(
          dispatch_message: ctx[:dispatch_message].to_s.strip,
          dispatch_message_from_template: ActiveModel::Type::Boolean.new.cast(ctx[:dispatch_message_from_template]) || false
        )
      end
    end
  end
end
