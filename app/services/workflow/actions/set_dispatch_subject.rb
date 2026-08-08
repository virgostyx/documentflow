# frozen_string_literal: true

module Workflow
  module Actions
    # Persists the EXP actor's subject override, read later by
    # NotificationMailer when AddresseeNotificationJob/CcNotificationJob run.
    # Optional, unlike dispatch_message - a blank value clears any previous
    # override and the mailer falls back to its default subject line.
    class SetDispatchSubject < ApplicationAction
      expects :step, :document

      executed do |ctx|
        next unless ctx.step.exp?

        ctx.document.update_column(:dispatch_subject, ctx[:dispatch_subject].to_s.strip.presence)
      end
    end
  end
end
