# frozen_string_literal: true

module Documents
  module Actions
    class EnqueuePdfConversion < ApplicationAction
      expects :document

      executed do |ctx|
        PdfConversionJob.perform_later(ctx.document.id)
      end
    end
  end
end
