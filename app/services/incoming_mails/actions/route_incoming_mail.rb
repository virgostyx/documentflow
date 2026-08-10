# frozen_string_literal: true

module IncomingMails
  module Actions
    class RouteIncomingMail < ApplicationAction
      expects :document, :current_user, :routing_params
      promises :document

      executed do |ctx|
        document = ctx.document

        if document.update(
          addressee_type: "User",
          addressee_id: ctx.routing_params[:action_user_id],
          routing_message: ctx.routing_params[:routing_message],
          expects_response: ctx.routing_params[:expects_response],
          response_deadline: ctx.routing_params[:response_deadline],
          in_reply_to_id: ctx.routing_params[:in_reply_to_id],
          routed_at: Time.current
        )
          ctx.document = document
          ctx[:user] = ctx.current_user
          ctx[:auditable] = document
          ctx[:action] = "route"
          ctx[:audit_changes] = {
            action_user_id: document.addressee_id,
            expects_response: document.expects_response,
            in_reply_to_id: document.in_reply_to_id
          }
        else
          fail_with!(ctx, document.errors.full_messages.to_sentence, :validation_error)
        end
      end
    end
  end
end
