# frozen_string_literal: true

module Workflow
  class AddStepFormComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    private

    attr_reader :document

    def role_options
      WorkflowStep::ROLES
    end

    def actor_options
      document.entity.users.merge(EntityUser.active).order(:first_name, :last_name)
              .map { |user| [ user.display_name, user.id ] }
    end
  end
end
