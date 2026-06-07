# frozen_string_literal: true

module Workflow
  class StepComponent < ViewComponent::Base
    STATUS_COLORS = {
      "pending" => :gray,
      "approved" => :success,
      "rejected" => :danger,
      "skipped" => :gray
    }.freeze

    def initialize(step:)
      @step = step
    end

    private

    attr_reader :step

    def status_color
      STATUS_COLORS.fetch(step.status, :gray)
    end
  end
end
