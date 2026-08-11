# frozen_string_literal: true

# Deliberately not entity-scoped, unlike CcRecipient: a DistributionList is
# personal and can outlive/cross the entities the owning user belongs to.
# Reconciliation against a specific document's entity happens at apply-time
# via Document#party_in_entity? (see the distribution-list organizers).
class DistributionListMember < ApplicationRecord
  include PartyAssignable

  belongs_to :distribution_list
  belongs_to :party, polymorphic: true

  party_assignable :party

  validates :party_id, uniqueness: { scope: %i[distribution_list_id party_type] }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :ordered, -> { order(:position) }
end
