# frozen_string_literal: true

class EmailTemplate < ApplicationRecord
  # Tags that resolve to a computed value (see Templates::RenderEmailBody)
  # instead of a value typed on the generation form - never get an
  # email_template_fields row. {{date}} resolves when the email body is
  # generated; {{recipient_name}} is deliberately left in the rendered text
  # and only resolved per-recipient when the email actually sends.
  RESERVED_TAGS = %w[date recipient_name].freeze

  # Associations
  belongs_to :entity
  belongs_to :department, optional: true
  belongs_to :created_by, class_name: "User"
  has_many :email_template_fields, -> { order(:position) }, dependent: :destroy, inverse_of: :email_template

  accepts_nested_attributes_for :email_template_fields

  # Validations
  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validates :body_template, presence: true
  validate :department_belongs_to_entity

  # Callbacks
  after_commit :sync_template_fields, on: %i[create update]

  # All tags currently referenced by this template's body, including
  # reserved ones that don't get an email_template_fields row.
  def tags
    Templates::TagScanner.tags_in(body_template)
  end

  private

  def department_belongs_to_entity
    return if entity.nil? || department.nil? || department.entity_id == entity_id

    errors.add(:department, "must belong to the same entity")
  end

  def sync_template_fields
    tag_names = tags - RESERVED_TAGS
    existing_tags = email_template_fields.pluck(:tag_name)

    new_tags = tag_names - existing_tags
    new_tags.each_with_index do |tag, index|
      email_template_fields.create!(
        tag_name: tag, label: tag.humanize, field_type: "text", required: true,
        position: next_field_position + index
      )
    end

    stale_tags = existing_tags - tag_names
    email_template_fields.where(tag_name: stale_tags).destroy_all if stale_tags.any?
  end

  def next_field_position
    (email_template_fields.maximum(:position) || 0) + 1
  end
end
