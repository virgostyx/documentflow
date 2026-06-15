# frozen_string_literal: true

module Documents
  class PartyPickerComponent < ViewComponent::Base
    include PartyOptionsHelper

    def initialize(form:, attribute:, entity:, label:, required: false, include_blank: nil, selected: nil)
      @form = form
      @attribute = attribute
      @entity = entity
      @label = label
      @required = required
      @include_blank = include_blank
      @selected = selected
    end

    def picker_id
      "#{form.object_name}_#{attribute}"
    end

    def grouped_options
      party_grouped_options(entity, selected)
    end

    def select_options
      include_blank ? { include_blank: include_blank } : {}
    end

    private

    attr_reader :form, :attribute, :entity, :label, :required, :include_blank, :selected
  end
end
