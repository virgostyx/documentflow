# frozen_string_literal: true

module Workflow
  class ActionButtonsComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document = document
      @current_user = current_user
      @policy = Pundit.policy!(current_user, document)
    end

    def show_approve?
      @policy.approve? && current_step&.actor == @current_user
    end

    def show_reject?
      @policy.reject? && current_step&.actor == @current_user && current_step&.role != "RED"
    end

    def show_cancel?
      @policy.cancel?
    end

    private

    attr_reader :document, :current_user

    def current_step
      @current_step ||= document.current_step
    end
  end
end
