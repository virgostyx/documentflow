# frozen_string_literal: true

class DocumentTemplateField < ApplicationRecord
  FIELD_TYPES = %w[text textarea number date select].freeze

  # Associations
  belongs_to :document_template

  # Validations
  validates :tag_name, presence: true, uniqueness: { scope: :document_template_id }
  validates :label, presence: true
  validates :field_type, presence: true, inclusion: { in: FIELD_TYPES }
  validates :position, presence: true
  validate :options_present_for_select_type

  # Scopes
  scope :ordered, -> { order(:position) }

  # Methods
  def options_text
    options&.join(", ")
  end

  def options_text=(value)
    self.options = value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  private

  def options_present_for_select_type
    return unless field_type == "select"
    return if options.present?

    errors.add(:options, "must have at least one value for a select field")
  end
end
