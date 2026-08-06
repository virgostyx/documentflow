# frozen_string_literal: true

module Templates
  module Actions
    class CreateAnnexes < ApplicationAction
      expects :document, :annex_files

      executed do |ctx|
        (ctx.annex_files || []).reject(&:blank?).each do |file|
          ctx.document.annexes.create(file: file)
        end
      end
    end
  end
end
