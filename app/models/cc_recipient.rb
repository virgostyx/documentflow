# frozen_string_literal: true

class CcRecipient < ApplicationRecord
  include PartyAssignable

  belongs_to :document
  belongs_to :party, polymorphic: true

  delegate :entity_id, to: :document

  party_assignable :party

  validates :party_id, uniqueness: { scope: %i[document_id party_type] }
  validate :party_belongs_to_entity

  after_save :update_document_search_text
  after_destroy :update_document_search_text

  private

  def update_document_search_text
    document.update_column(:search_text, Document.compute_search_text(document))
  end

  def party_belongs_to_entity
    return if document.nil? || party.nil? || party_in_entity?(party)

    errors.add(:party, "must belong to the same entity")
  end
end
