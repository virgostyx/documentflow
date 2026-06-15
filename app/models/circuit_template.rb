# frozen_string_literal: true

class CircuitTemplate < ApplicationRecord
  # Associations
  belongs_to :entity
  has_many :circuit_template_steps, -> { order(:order) }, dependent: :destroy, inverse_of: :circuit_template

  accepts_nested_attributes_for :circuit_template_steps, allow_destroy: true

  # Validations
  validates :name, presence: true, uniqueness: { scope: :entity_id }
end
