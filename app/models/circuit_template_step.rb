# frozen_string_literal: true

class CircuitTemplateStep < ApplicationRecord
  ROLES = WorkflowStep::ROLES

  # Associations
  belongs_to :circuit_template
  belongs_to :actor, class_name: "User", optional: true

  # Validations
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :order, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Scopes
  scope :ordered, -> { order(:order) }

  # Methods
  def parallel?
    is_parallel
  end
end
