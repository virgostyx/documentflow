# frozen_string_literal: true

module Ui
  class ButtonComponent < ViewComponent::Base
    VARIANTS = {
      primary: "bg-primary-600 text-white hover:bg-primary-700 focus:ring-primary-500",
      secondary: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-primary-500",
      danger: "bg-danger-600 text-white hover:bg-danger-700 focus:ring-danger-500"
    }.freeze

    BASE_CLASSES = "inline-flex items-center justify-center gap-2 rounded-md px-4 py-2 text-sm font-medium " \
                   "transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 " \
                   "disabled:opacity-50 disabled:cursor-not-allowed"

    def initialize(href: nil, variant: :primary, method: nil, **html_options)
      @href = href
      @variant = variant
      @method = method
      @html_options = html_options
    end

    def classes
      "#{BASE_CLASSES} #{VARIANTS[@variant] || VARIANTS[:primary]}"
    end

    def link?
      @href.present?
    end

    def link_options
      options = @html_options.dup
      options[:class] = "#{classes} #{options[:class]}".strip
      if @method
        options[:data] = (options[:data] || {}).merge(turbo_method: @method)
      end
      options
    end

    def button_options
      options = @html_options.dup
      options[:type] ||= "submit"
      options[:class] = "#{classes} #{options[:class]}".strip
      options
    end
  end
end
