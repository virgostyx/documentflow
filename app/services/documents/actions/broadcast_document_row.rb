# frozen_string_literal: true

module Documents
  module Actions
    class BroadcastDocumentRow < ApplicationAction
      expects :document

      executed do |ctx|
        DocumentRowBroadcastJob.perform_later(ctx.document.id)
      end
    end
  end
end
