# frozen_string_literal: true

module Workflow
  module Actions
    # Requires a non-blank dispatch message before an EXP step can be approved,
    # since the message replaces the mailer's structural sentence - a document
    # must never dispatch with an empty body. Runs before ApproveStep so a
    # missing message never leaves the step partially approved.
    class ValidateDispatchMessage < ApplicationAction
      expects :step

      executed do |ctx|
        next unless ctx.step.exp?

        next unless ctx[:dispatch_message].to_s.strip.blank?

        fail_with!(ctx, "A message is required to dispatch this document", :validation_error)
      end
    end
  end
end
