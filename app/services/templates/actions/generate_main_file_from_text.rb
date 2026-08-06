# frozen_string_literal: true

module Templates
  module Actions
    class GenerateMainFileFromText < ApplicationAction
      expects :document, :rendered_body

      executed do |ctx|
        filename = "#{ctx.document.subject.parameterize.presence || 'document'}.pdf"
        ctx.document.main_file.attach(RenderTextToPdf.call(ctx.rendered_body, filename: filename))
      end
    end
  end
end
