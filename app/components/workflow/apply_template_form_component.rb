# frozen_string_literal: true

module Workflow
  class ApplyTemplateFormComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    def render?
      circuit_templates.any?
    end

    private

    attr_reader :document

    def circuit_templates
      document.entity.circuit_templates.order(:name)
    end
  end
end
