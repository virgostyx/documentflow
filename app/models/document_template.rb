# frozen_string_literal: true

class DocumentTemplate < ApplicationRecord
  include PartyAssignable
  include EntityScopedAssociations
  include SyncsTemplateFields

  TAG_PATTERN = Templates::TagScanner::TAG_PATTERN
  DOCX_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  SOURCE_FILE_MAX_SIZE = 10.megabytes

  # Tags that resolve to a computed value (see Templates::Actions::InjectComputedFieldValues)
  # instead of a value typed on the generation form - never get a document_template_fields row.
  RESERVED_TAGS = %w[date].freeze

  # Associations
  belongs_to :entity
  belongs_to :department, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :circuit_template, optional: true
  belongs_to :default_sender, polymorphic: true, optional: true
  belongs_to :default_addressee, polymorphic: true, optional: true
  has_many :document_template_fields, -> { order(:position) }, dependent: :destroy, inverse_of: :document_template
  has_one_attached :source_file

  accepts_nested_attributes_for :document_template_fields

  party_assignable :default_sender, :default_addressee

  syncs_template_fields :document_template_fields

  # Validations
  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validates :subject_template, presence: true
  validates_entity_scoped :department
  validate :default_sender_belongs_to_entity
  validate :default_addressee_belongs_to_entity
  validate :source_file_must_be_a_valid_docx

  # All tags currently referenced by this template (subject + docx body),
  # including reserved ones that don't get a document_template_fields row.
  def tags
    extract_tags
  end

  private

  def source_file_must_be_a_valid_docx
    unless source_file.attached?
      errors.add(:source_file, "must be attached")
      return
    end

    if source_file.content_type != DOCX_CONTENT_TYPE
      errors.add(:source_file, "must be a Word (.docx) file")
    end

    if source_file.blob.byte_size > SOURCE_FILE_MAX_SIZE
      errors.add(:source_file, "must be smaller than #{SOURCE_FILE_MAX_SIZE / 1.megabyte}MB")
    end
  end

  def default_sender_belongs_to_entity
    return if entity.nil? || party_in_entity?(default_sender)

    errors.add(:default_sender, "must belong to the same entity")
  end

  def default_addressee_belongs_to_entity
    return if entity.nil? || party_in_entity?(default_addressee)

    errors.add(:default_addressee, "must belong to the same entity")
  end

  def extract_tags
    tags = Templates::TagScanner.tags_in(subject_template)
    tags += docx_tags if source_file.attached?
    tags.uniq
  end

  def docx_tags
    source_file.open { |file| Templates::DocxTemplateProcessor.tags_in(file.path) }
  rescue StandardError => e
    Rails.logger.warn("[DocumentTemplate##{id}] could not scan source_file for tags: #{e.message}")
    []
  end
end
