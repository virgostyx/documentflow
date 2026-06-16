# frozen_string_literal: true

module Documents
  class PartyPickerComponent < ViewComponent::Base
    include PartyOptionsHelper

    def initialize(form:, attribute:, entity:, label:, required: false, include_blank: nil, selected: nil, show_new_contact: true, additional_picker_ids: [], internal_only: false)
      @form = form
      @attribute = attribute
      @entity = entity
      @label = label
      @required = required
      @include_blank = include_blank
      @selected = selected
      @show_new_contact = show_new_contact
      @additional_picker_ids = additional_picker_ids
      @internal_only = internal_only
    end

    def picker_id
      "#{form.object_name}_#{attribute}"
    end

    def grouped_options
      if @internal_only
        party_internal_options(entity, selected)
      else
        party_grouped_options(entity, selected)
      end
    end

    def select_options
      include_blank ? { include_blank: include_blank } : {}
    end

    def show_new_contact?
      @show_new_contact
    end

    private

    attr_reader :form, :attribute, :entity, :label, :required, :include_blank, :selected, :additional_picker_ids
  end
end
