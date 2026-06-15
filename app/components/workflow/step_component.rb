# frozen_string_literal: true

module Workflow
  class StepComponent < ViewComponent::Base
    STATUS_COLORS = {
      "pending" => :gray,
      "approved" => :success,
      "rejected" => :danger,
      "skipped" => :gray
    }.freeze

    def initialize(step:, manageable: false, first: false, last: false)
      @step = step
      @manageable = manageable
      @first = first
      @last = last
    end

    def manageable?
      @manageable
    end

    def first?
      @first
    end

    def last?
      @last
    end

    private

    attr_reader :step

    def status_color
      STATUS_COLORS.fetch(step.status, :gray)
    end
  end
end
