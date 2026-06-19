# frozen_string_literal: true

module Ui
  class ModalComponent < ViewComponent::Base
    def initialize(id: "modal")
      @id = id
    end
  end
end
