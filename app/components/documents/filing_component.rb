# frozen_string_literal: true

module Documents
  class FilingComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document = document
      @policy = Pundit.policy!(current_user, document)
    end

    def classification_node
      document.classification_node
    end

    def path_nodes
      return [] unless classification_node

      nodes = [ classification_node ]
      nodes.prepend(nodes.first.parent) while nodes.first.parent

      nodes
    end

    def show_actions?
      @policy.classify?
    end

    private

    attr_reader :document
  end
end
