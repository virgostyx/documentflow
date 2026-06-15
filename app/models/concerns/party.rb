# frozen_string_literal: true

# Shared interface for entities that can act as a sender, addressee or CC
# recipient on a Document: internal Users and external Contacts.
module Party
  extend ActiveSupport::Concern

  def display_name
    full_name
  end

  def internal?
    is_a?(User)
  end

  def external?
    is_a?(Contact)
  end
end
