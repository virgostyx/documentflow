# frozen_string_literal: true

class Document < ApplicationRecord
  include AASM
  include PartyAssignable

  STATUSES = %w[draft in_progress signed finalized cancelled].freeze

  SORTABLE_COLUMNS = {
    "reference_number" => "documents.reference_number",
    "subject"          => "documents.subject",
    "document_date"    => "documents.document_date",
    "status"           => "documents.status",
    "created_at"       => "documents.created_at"
  }.freeze
  DEFAULT_SORT_COLUMN = "document_date"
  DEFAULT_SORT_DIRECTION = "desc"

  # Associations
  belongs_to :entity
  belongs_to :created_by, class_name: "User"
  belongs_to :sender, polymorphic: true
  belongs_to :addressee, polymorphic: true
  has_many :workflow_steps, dependent: :destroy
  has_many :shared_links, dependent: :destroy
  has_many :cc_recipients, dependent: :destroy
  has_many :audit_logs, as: :auditable, dependent: :destroy
  has_one_attached :main_file
  has_many_attached :annexes

  party_assignable :sender, :addressee

  # Validations
  validates :subject, presence: true, length: { maximum: 255 }
  validates :document_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :sender_belongs_to_entity
  validate :addressee_belongs_to_entity

  # Scopes
  scope :authored_by, ->(user) { where(created_by: user) }
  scope :received_by, ->(user) { joins(:workflow_steps).where(workflow_steps: { actor_id: user.id }).distinct }
  scope :with_status, ->(status) { status.present? ? where(status: status) : all }
  scope :sorted, ->(column, direction) {
    col = SORTABLE_COLUMNS.fetch(column.to_s, SORTABLE_COLUMNS[DEFAULT_SORT_COLUMN])
    dir = %w[asc desc].include?(direction.to_s) ? direction.to_s : DEFAULT_SORT_DIRECTION
    order(Arel.sql("#{col} #{dir}, documents.created_at #{dir}"))
  }

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
    return if entity.nil? || party_in_entity?(sender)

    errors.add(:sender, "must belong to the same entity")
  end

  def addressee_belongs_to_entity
    return if entity.nil? || party_in_entity?(addressee)

    errors.add(:addressee, "must belong to the same entity")
  end
end
