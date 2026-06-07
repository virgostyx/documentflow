# frozen_string_literal: true

module Workflow
  module Actions
    class ReturnToPreviousStep < ApplicationAction
      expects :document, :step
      promises :previous_step

      executed do |ctx|
        previous_step = ctx.document.workflow_steps.where("\"order\" < ?", ctx.step.order).ordered.last

        unless previous_step
          next fail_with!(ctx, "Aucune étape précédente vers laquelle revenir", :business_logic_error)
        end

        previous_step.update!(status: "pending")
        ctx.previous_step = previous_step
      end
    end
  end
end
