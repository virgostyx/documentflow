# frozen_string_literal: true

# Provides a "<name>_token" virtual accessor (e.g. "User-5" / "Contact-12")
# backed by a "<name>_type"/"<name>_id" polymorphic association, for use with
# grouped <select> inputs that mix internal Users and external Contacts.
module PartyAssignable
  extend ActiveSupport::Concern

  class_methods do
    def party_assignable(*names)
      names.each do |name|
        define_method("#{name}_token=") do |token|
          type, id = token.to_s.split("-", 2)
          public_send("#{name}_type=", type.presence)
          public_send("#{name}_id=", id.presence)
        end

        define_method("#{name}_token") do
          id = public_send("#{name}_id")
          id ? "#{public_send("#{name}_type")}-#{id}" : nil
        end
      end
    end
  end

  def party_in_entity?(party)
    return true if party.nil?

    case party
    when Contact then party.entity_id == entity_id
    when User then EntityUser.active.exists?(entity_id: entity_id, user_id: party.id)
    end
  end
end
