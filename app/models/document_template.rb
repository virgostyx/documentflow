# frozen_string_literal: true

class DocumentTemplate < ApplicationRecord
  include PartyAssignable

  TAG_PATTERN = /\{\{(\w+)\}\}/
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

  # Validations
  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validates :subject_template, presence: true
  validate :department_belongs_to_entity
  validate :default_sender_belongs_to_entity
  validate :default_addressee_belongs_to_entity
  validate :source_file_must_be_a_valid_docx

  # Callbacks
  #
  # Must be after_commit, not after_save: has_one_attached only uploads the
  # blob's actual bytes to the storage service on after_commit (see
  # ActiveStorage::Attached::Model#has_one_attached) - reading source_file
  # any earlier (e.g. in after_save) would race the upload and silently see
  # an empty/missing file.
  after_commit :sync_template_fields, on: %i[create update]

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
    tags = extract_tags - RESERVED_TAGS
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
    tags = subject_template.to_s.scan(TAG_PATTERN).flatten
    tags += docx_tags if source_file.attached?
    tags.uniq
  end

  def docx_tags
    source_file.open { |file| Templates::DocxTemplateProcessor.tags_in(file.path) }
  rescue StandardError => e
    Rails.logger.warn("[DocumentTemplate##{id}] could not scan source_file for tags: #{e.message}")
    []
  end

  def next_field_position
    (document_template_fields.maximum(:position) || 0) + 1
  end
end
