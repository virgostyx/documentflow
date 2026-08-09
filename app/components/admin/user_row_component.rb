# frozen_string_literal: true

module Admin
  class UserRowComponent < ViewComponent::Base
    def initialize(user:)
      @user = user
    end

    private

    attr_reader :user
  end
end
