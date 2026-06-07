# frozen_string_literal: true

module Documents
  module Actions
    class CompleteRedStep < ApplicationAction
      expects :document

      executed do |ctx|
        red_step = ctx.document.workflow_steps.ordered.find_by(role: "RED")
        red_step&.update!(status: "approved")
      end
    end
  end
end
