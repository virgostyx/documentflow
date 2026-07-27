# frozen_string_literal: true

class CircuitTemplate < ApplicationRecord
  # Associations
  belongs_to :entity
  has_many :circuit_template_steps, -> { order(:order) }, dependent: :destroy, inverse_of: :circuit_template

  accepts_nested_attributes_for :circuit_template_steps, allow_destroy: true

  # Validations
  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validate :must_include_sign_step

  private

  # Deliberately avoids reading/loading the `circuit_template_steps`
  # association proxy itself (e.g. via `.to_a`/`.any?`), since doing so
  # would cache it -- and any step created afterward directly through
  # `CircuitTemplateStep` (bypassing this association, as e.g. some tests
  # and the circuit-template-cloning code do) would then be invisible to
  # future reads of `circuit_template_steps` on this same in-memory object.
  #
  # Instead, combine:
  #   - `circuit_template_steps.target`: whatever is already built/loaded
  #     in memory (new nested-attribute records, or existing ones that were
  #     loaded and possibly marked for destruction) -- reading `.target`
  #     never triggers a query or caches anything.
  #   - a plain, one-off query for persisted steps not already represented
  #     in that target, to account for existing steps the current nested
  #     attributes payload didn't mention (left untouched by Rails).
  def must_include_sign_step
    roles = pending_step_roles
    return if roles.empty?
    return if roles.include?("SIGN")

    errors.add(:base, "Circuit must include a SIGN step")
  end

  def pending_step_roles
    target = circuit_template_steps.target
    target_ids = target.map(&:id).compact

    persisted_roles =
      if persisted?
        relation = CircuitTemplateStep.where(circuit_template_id: id)
        relation = relation.where.not(id: target_ids) if target_ids.any?
        relation.pluck(:role)
      else
        []
      end

    persisted_roles + target.reject(&:marked_for_destruction?).map(&:role)
  end
end
