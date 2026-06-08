# frozen_string_literal: true

class FlashMessageComponentPreview < ViewComponent::Preview
  def notice
    render(FlashMessageComponent.new(type: :notice, message: "Document created successfully."))
  end

  def alert
    render(FlashMessageComponent.new(type: :alert, message: "This document cannot be cancelled in its current state."))
  end

  def error
    render(FlashMessageComponent.new(type: :error, message: "Something went wrong. Please try again."))
  end

  def info
    render(FlashMessageComponent.new(type: :info, message: "Your share link expires in 7 days."))
  end
end
