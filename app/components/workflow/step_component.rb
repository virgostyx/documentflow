# frozen_string_literal: true

module Workflow
  class StepComponent < ViewComponent::Base
    STATUS_COLORS = {
      "pending" => :gray,
      "approved" => :success,
      "rejected" => :danger,
      "skipped" => :gray
    }.freeze

    def initialize(step:, manageable: false, reassignable: false)
      @step = step
      @manageable = manageable
      @reassignable = reassignable
    end

    def manageable?
      @manageable
    end

    def reassignable?
      @reassignable
    end

    private

    attr_reader :step

    def status_color
      STATUS_COLORS.fetch(step.status, :gray)
    end

    def reassignment_options
      step.document.entity.users.merge(EntityUser.active)
          .where.not(id: step.actor_id)
          .order(:first_name, :last_name)
          .map { |user| [ user.display_name, user.id ] }
    end
  end
end
