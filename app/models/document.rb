# frozen_string_literal: true

class Document < ApplicationRecord
  include AASM

  STATUSES = %w[draft in_progress signed finalized cancelled].freeze

  # Associations
  belongs_to :entity
  belongs_to :created_by, class_name: "User"
  belongs_to :sender, class_name: "Contact"
  belongs_to :addressee, class_name: "Contact"
  has_many :workflow_steps, dependent: :destroy
  has_many :shared_links, dependent: :destroy
  has_many :audit_logs, as: :auditable, dependent: :destroy
  has_many_attached :files

  accepts_nested_attributes_for :workflow_steps, allow_destroy: true, reject_if: :all_blank

  # Validations
  validates :subject, presence: true, length: { maximum: 255 }
  validates :document_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :sender_belongs_to_entity
  validate :addressee_belongs_to_entity

  # Callbacks
  before_validation :generate_reference_number, on: :create

  # State machine
  aasm column: :status do
    state :draft, initial: true
    state :in_progress
    state :signed
    state :finalized
    state :cancelled

    event :launch do
      transitions from: :draft, to: :in_progress
    end

    event :sign do
      transitions from: :in_progress, to: :signed
    end

    event :finalize do
      transitions from: :signed, to: :finalized, after: :freeze_document
    end

    event :cancel do
      transitions from: [ :draft, :in_progress, :signed ], to: :cancelled
    end
  end

  # Methods
  def frozen?
    is_frozen
  end

  def current_step
    workflow_steps.ordered.find_by(status: "pending")
  end

  private

  def generate_reference_number
    return if reference_number.present?
    return unless entity

    year = document_date&.year || Date.current.year
    last = entity.documents.where("reference_number LIKE ?", "#{year}/%").maximum(:reference_number)
    reference = last ? ReferenceNumber.parse(last).next : ReferenceNumber.first_for(year)
    self.reference_number = reference.to_s
  end

  def freeze_document
    update_column(:is_frozen, true)
  end

  def sender_belongs_to_entity
    return if sender.nil? || entity.nil? || sender.entity_id == entity_id

    errors.add(:sender, "must belong to the same entity")
  end

  def addressee_belongs_to_entity
    return if addressee.nil? || entity.nil? || addressee.entity_id == entity_id

    errors.add(:addressee, "must belong to the same entity")
  end
end
