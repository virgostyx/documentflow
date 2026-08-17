# frozen_string_literal: true

module Templates
  module Actions
    class CreateAnnexes < ApplicationAction
      expects :document, :annex_files
      expects :skip_pdf_conversion, default: false

      executed do |ctx|
        (ctx.annex_files || []).reject(&:blank?).each do |file|
          ctx.document.annexes.create(file: file, skip_pdf_conversion: ctx.skip_pdf_conversion)
        end
      end
    end
  end
end
