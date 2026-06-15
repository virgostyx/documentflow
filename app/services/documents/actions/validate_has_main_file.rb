# frozen_string_literal: true

module Documents
  module Actions
    class ValidateHasMainFile < ApplicationAction
      expects :document

      executed do |ctx|
        unless ctx.document.main_file.attached?
          fail_with!(ctx, "This document has no main document attached", :validation_error)
        end
      end
    end
  end
end
