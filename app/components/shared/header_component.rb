# frozen_string_literal: true

module Shared
  class HeaderComponent < ViewComponent::Base
    attr_reader :current_user

    def initialize(current_user:)
      @current_user = current_user
    end
  end
end
