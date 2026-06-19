# frozen_string_literal: true

module Ui
  class ModalComponentPreview < ViewComponent::Preview
    def default
      render(Ui::ModalComponent.new)
    end
  end
end
