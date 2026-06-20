# frozen_string_literal: true

module IncomingMails
  module Actions
    class CreateInfoRecipients < ApplicationAction
      expects :document, :routing_params

      executed do |ctx|
        Array(ctx.routing_params[:info_user_ids]).reject(&:blank?).each do |user_id|
          ctx.document.cc_recipients.find_or_create_by!(party_type: "User", party_id: user_id)
        end
      end
    end
  end
end
