# frozen_string_literal: true

module Ui
  class FilterPanelComponent < ViewComponent::Base
    renders_one :search
    renders_one :fields

    def initialize(active_count: 0, open: false, clear_href: nil)
      @active_count = active_count.to_i
      @open = open
      @clear_href = clear_href
    end

    def show_clear?
      @clear_href.present? && (@active_count > 0 || @open)
    end

    def open_by_default?
      @active_count > 0 || @open
    end
  end
end
