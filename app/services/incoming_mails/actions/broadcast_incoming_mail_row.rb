# frozen_string_literal: true

module IncomingMails
  module Actions
    class BroadcastIncomingMailRow < ApplicationAction
      expects :document

      executed do |ctx|
        IncomingMailRowBroadcastJob.perform_later(ctx.document.id)
      end
    end
  end
end
