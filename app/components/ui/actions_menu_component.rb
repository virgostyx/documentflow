# frozen_string_literal: true

module Ui
  class ActionsMenuComponent < ViewComponent::Base
    renders_many :items, "ItemComponent"

    def initialize(label: "Actions")
      @label = label
    end

    def render?
      items.any?
    end

    class ItemComponent < ViewComponent::Base
      VARIANTS = {
        default: "text-gray-700 hover:bg-gray-50",
        danger: "text-danger-600 hover:bg-danger-50"
      }.freeze

      def initialize(href:, method: nil, variant: :default, **html_options)
        @href = href
        @method = method
        @variant = variant
        @html_options = html_options
      end

      def call
        options = @html_options.dup
        options[:class] = "block w-full text-left px-4 py-2 text-sm transition-colors #{VARIANTS[@variant] || VARIANTS[:default]} #{options[:class]}".strip
        options[:role] = "menuitem"
        options[:data] = (options[:data] || {}).merge(turbo_method: @method) if @method

        link_to content, @href, **options
      end
    end
  end
end
