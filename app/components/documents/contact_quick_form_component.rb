# frozen_string_literal: true

module Documents
  class ContactQuickFormComponent < ViewComponent::Base
    def initialize(entity:, picker_id:, contact: nil, open: false)
      @entity = entity
      @picker_id = picker_id
      @contact = contact || entity.contacts.new
      @open = open
    end

    def open?
      @open
    end

    private

    attr_reader :entity, :picker_id, :contact
  end
end
