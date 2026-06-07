# frozen_string_literal: true

module Ui
  class EmptyStateComponent < ViewComponent::Base
    renders_one :action

    attr_reader :title, :description

    def initialize(title:, description: nil)
      @title = title
      @description = description
    end
  end
end
