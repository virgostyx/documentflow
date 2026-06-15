# frozen_string_literal: true

module Documents
  class MainFileComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document = document
      @policy = Pundit.policy!(current_user, document)
    end

    def attached?
      document.main_file.attached?
    end

    def show_actions?
      @policy.update?
    end

    private

    attr_reader :document
  end
end
