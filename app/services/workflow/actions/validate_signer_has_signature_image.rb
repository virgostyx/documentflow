# frozen_string_literal: true

module Workflow
  module Actions
    class ValidateSignerHasSignatureImage < ApplicationAction
      expects :step, :current_user

      executed do |ctx|
        next unless ctx.step.sign?

        unless ctx.current_user.signature_image.present?
          next fail_with!(ctx, "Please register your signature before signing this document.", :validation_error)
        end
      end
    end
  end
end
