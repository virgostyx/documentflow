# frozen_string_literal: true

class CcRecipient < ApplicationRecord
  include PartyAssignable

  belongs_to :document
  belongs_to :party, polymorphic: true

  delegate :entity_id, to: :document

  party_assignable :party

  validates :party_id, uniqueness: { scope: %i[document_id party_type] }
  validate :party_belongs_to_entity

  private

  def party_belongs_to_entity
    return if document.nil? || party.nil? || party_in_entity?(party)

    errors.add(:party, "must belong to the same entity")
  end
end
