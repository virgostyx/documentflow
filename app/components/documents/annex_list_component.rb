# frozen_string_literal: true

module Documents
  class AnnexListComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document = document
      @policy = Pundit.policy!(current_user, document)
    end

    def annexes
      document.annexes
    end

    def show_actions?
      @policy.update?
    end

    private

    attr_reader :document
  end
end
