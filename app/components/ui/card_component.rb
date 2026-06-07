# frozen_string_literal: true

module Ui
  class CardComponent < ViewComponent::Base
    renders_one :header
    renders_one :footer
  end
end
