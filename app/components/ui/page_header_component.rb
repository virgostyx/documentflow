# frozen_string_literal: true

module Ui
  class PageHeaderComponent < ViewComponent::Base
    attr_reader :title, :description, :back_path, :back_text

    def initialize(title:, description: nil, back_path: nil, back_text: "Back")
      @title = title
      @description = description
      @back_path = back_path
      @back_text = back_text
    end
  end
end
