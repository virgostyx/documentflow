# frozen_string_literal: true

module Workflow
  module Actions
    # Confirms the SIGN-step actor completed a fresh WebAuthn step-up
    # ceremony (StepUpChallenge concern) for this exact step: ctx[:step_up_token]
    # (submitted with the approve request) must match the single-use, step-scoped
    # token minted into ctx[:step_up_tokens] and not yet expired.
    class ValidateStepUpChallenge < ApplicationAction
      expects :step, :current_user

      executed do |ctx|
        next unless ctx.step.sign?

        tokens = ctx[:step_up_tokens] || {}
        entry = tokens[ctx.step.id.to_s]
        provided = ctx[:step_up_token].to_s

        if entry.blank? || provided.blank?
          next fail_with!(ctx, "Please verify your identity before signing this document.", :permission_error)
        end

        unless ActiveSupport::SecurityUtils.secure_compare(entry["token"].to_s, provided)
          next fail_with!(ctx, "Verification failed. Please try again.", :permission_error)
        end

        if entry["expires_at"].to_i < Time.current.to_i
          next fail_with!(ctx, "Verification expired. Please try again.", :permission_error)
        end
      end
    end
  end
end
