# frozen_string_literal: true

module IncomingMails
  module Actions
    class ValidateReplyLink < ApplicationAction
      expects :document, :current_user, :routing_params

      executed do |ctx|
        in_reply_to_id = ctx.routing_params[:in_reply_to_id]

        if in_reply_to_id.present?
          candidates = Pundit.policy_scope(ctx.current_user, Document)
                              .where(entity: ctx.document.entity)
                              .repliable_by(ctx.document.sender)

          unless candidates.exists?(id: in_reply_to_id)
            fail_with!(ctx, "Selected document is not a valid reply target", :validation_error)
          end
        end
      end
    end
  end
end
