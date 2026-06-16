# frozen_string_literal: true

module Documents
  class ContactQuickFormComponent < ViewComponent::Base
    FIELDS = [
      { attribute: :first_name, label: "First name", target: "firstName", type: "text", required: true, wrapper_class: nil },
      { attribute: :last_name, label: "Last name", target: "lastName", type: "text", required: true, wrapper_class: nil },
      { attribute: :email, label: "Email", target: "email", type: "email", required: true, wrapper_class: "sm:col-span-2" },
      { attribute: :company, label: "Company", target: "company", type: "text", required: false, wrapper_class: nil },
      { attribute: :phone, label: "Phone", target: "phone", type: "text", required: false, wrapper_class: nil }
    ].freeze

    def initialize(entity:, picker_id:, contact: nil, open: false)
      @entity = entity
      @picker_id = picker_id
      @contact = contact || entity.contacts.new
      @open = open
    end

    def open?
      @open
    end

    def fields
      FIELDS
    end

    def field_id(attribute)
      "#{picker_id}_#{attribute}"
    end

    def field_value(attribute)
      contact.public_send(attribute).to_s
    end

    def field_error(attribute)
      contact.errors[attribute].first
    end

    def field_label(field)
      label = field[:label]
      label += ' <span class="text-red-500">*</span>' if field[:required]
      label.html_safe
    end

    def input_classes(attribute)
      classes = "block w-full px-3 pt-6 pb-2 text-gray-900 bg-white border border-gray-300 rounded-lg appearance-none focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent peer"
      classes += " border-red-500 focus:ring-red-500" if contact.errors[attribute].any?
      classes
    end

    def label_classes(attribute)
      classes = "absolute text-gray-500 duration-300 transform -translate-y-3 scale-75 top-4 left-3 z-10 origin-[0] peer-placeholder-shown:scale-100 peer-placeholder-shown:translate-y-0 peer-focus:scale-75 peer-focus:-translate-y-3 peer-focus:text-blue-600"
      classes += " text-red-600" if contact.errors[attribute].any?
      classes
    end

    private

    attr_reader :entity, :picker_id, :contact
  end
end
