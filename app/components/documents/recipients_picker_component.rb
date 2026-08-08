# frozen_string_literal: true

module Documents
  class RecipientsPickerComponent < ViewComponent::Base
    def initialize(entity:, name: "party_tokens[]", exclude_tokens: [])
      @entity = entity
      @name = name
      @exclude_tokens = exclude_tokens
    end

    def grouped_parties
      internal = entity.users.merge(EntityUser.active).order(:first_name, :last_name)
                       .map { |user| [ user.display_name, "User-#{user.id}" ] }
      external = entity.contacts.order(:last_name, :first_name)
                       .map { |contact| [ contact.display_name, "Contact-#{contact.id}" ] }

      { "Internal users" => internal.reject { |_, token| exclude_tokens.include?(token) },
        "External contacts" => external.reject { |_, token| exclude_tokens.include?(token) } }
    end

    private

    attr_reader :entity, :name, :exclude_tokens
  end
end
