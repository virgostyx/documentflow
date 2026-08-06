# frozen_string_literal: true

class DocumentTemplate < ApplicationRecord
  include PartyAssignable

  TAG_PATTERN = /\{\{(\w+)\}\}/

  # Associations
  belongs_to :entity
  belongs_to :department, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :circuit_template, optional: true
  belongs_to :default_sender, polymorphic: true, optional: true
  belongs_to :default_addressee, polymorphic: true, optional: true
  has_many :document_template_fields, -> { order(:position) }, dependent: :destroy, inverse_of: :document_template

  accepts_nested_attributes_for :document_template_fields

  party_assignable :default_sender, :default_addressee

  # Validations
  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validates :subject_template, presence: true
  validates :body_template, presence: true
  validate :department_belongs_to_entity
  validate :default_sender_belongs_to_entity
  validate :default_addressee_belongs_to_entity

  # Callbacks
  after_save :sync_template_fields

  private

  def department_belongs_to_entity
    return if entity.nil? || department.nil? || department.entity_id == entity_id

    errors.add(:department, "must belong to the same entity")
  end

  def default_sender_belongs_to_entity
    return if entity.nil? || party_in_entity?(default_sender)

    errors.add(:default_sender, "must belong to the same entity")
  end

  def default_addressee_belongs_to_entity
    return if entity.nil? || party_in_entity?(default_addressee)

    errors.add(:default_addressee, "must belong to the same entity")
  end

  def sync_template_fields
    tags = extract_tags
    existing_tags = document_template_fields.pluck(:tag_name)

    new_tags = tags - existing_tags
    new_tags.each_with_index do |tag, index|
      document_template_fields.create!(
        tag_name: tag, label: tag.humanize, field_type: "text", required: true,
        position: next_field_position + index
      )
    end

    stale_tags = existing_tags - tags
    document_template_fields.where(tag_name: stale_tags).destroy_all if stale_tags.any?
  end

  def extract_tags
    "#{subject_template} #{body_template}".scan(TAG_PATTERN).flatten.uniq
  end

  def next_field_position
    (document_template_fields.maximum(:position) || 0) + 1
  end
end
