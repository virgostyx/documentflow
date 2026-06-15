# frozen_string_literal: true

module Workflow
  class StepsComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document = document
      @current_user = current_user
      @policy = Pundit.policy!(current_user, document)
    end

    def manageable?
      document.draft? && @policy.update?
    end

    private

    attr_reader :document, :current_user

    def steps
      document.workflow_steps.ordered
    end
  end
end
