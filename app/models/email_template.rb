# frozen_string_literal: true

class EmailTemplate < ApplicationRecord
  include EntityScopedAssociations
  include SyncsTemplateFields

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

  syncs_template_fields :email_template_fields

  # Validations
  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validates :body_template, presence: true
  validates_entity_scoped :department

  # All tags currently referenced by this template's subject and body,
  # including reserved ones that don't get an email_template_fields row.
  def tags
    (Templates::TagScanner.tags_in(subject_template) + Templates::TagScanner.tags_in(body_template)).uniq
  end
end
