# frozen_string_literal: true

class Document < ApplicationRecord
  include AASM
  include PartyAssignable

  STATUSES = %w[draft in_progress signed finalized cancelled].freeze
  DIRECTIONS = %w[outgoing incoming].freeze

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
  belongs_to :department
  belongs_to :created_by, class_name: "User"
  belongs_to :sender, polymorphic: true
  belongs_to :addressee, polymorphic: true
  belongs_to :in_reply_to, class_name: "Document", optional: true
  belongs_to :folder, optional: true
  belongs_to :lead_user, class_name: "User", optional: true
  belongs_to :checked_out_by, class_name: "User", optional: true
  has_many :replies, class_name: "Document", foreign_key: :in_reply_to_id, inverse_of: :in_reply_to, dependent: :nullify
  has_many :workflow_steps, dependent: :destroy
  has_many :shared_links, dependent: :destroy
  has_many :cc_recipients, dependent: :destroy
  has_many :audit_logs, as: :auditable, dependent: :destroy
  has_many :document_file_versions, dependent: :destroy
  has_one_attached :main_file
  has_many_attached :annexes

  party_assignable :sender, :addressee

  # Not persisted; only used to redisplay the incoming mail routing form after a validation failure.
  attr_accessor :action_user_id, :info_user_ids

  # Validations
  validates :subject, presence: true, length: { maximum: 255 }
  validates :document_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validate :sender_belongs_to_entity
  validate :addressee_belongs_to_entity
  validate :department_belongs_to_entity
  validate :in_reply_to_belongs_to_entity
  validate :folder_belongs_to_department
  validate :lead_user_belongs_to_entity

  # Scopes
  scope :authored_by, ->(user) { where(created_by: user) }
  scope :received_by, ->(user) {
    left_joins(:cc_recipients).where(
      "(documents.addressee_type = 'User' AND documents.addressee_id = :user_id) " \
      "OR (cc_recipients.party_type = 'User' AND cc_recipients.party_id = :user_id)",
      user_id: user.id
    ).distinct
  }
  scope :todo_for, ->(user) {
    where(addressee_type: "User", addressee_id: user.id, expects_response: true)
  }
  scope :waiting_for, ->(user) {
    where(created_by: user, expects_response: true)
  }
  scope :info_for, ->(user) {
    left_joins(:cc_recipients).where(
      "(" \
        "(documents.addressee_type = 'User' AND documents.addressee_id = :user_id AND documents.expects_response = false) " \
        "OR (documents.created_by_id = :user_id AND documents.expects_response = false) " \
        "OR (cc_recipients.party_type = 'User' AND cc_recipients.party_id = :user_id)" \
      ")",
      user_id: user.id
    ).distinct
  }
  scope :incoming, -> { where(direction: "incoming") }
  scope :outgoing, -> { where(direction: "outgoing") }
  scope :pending_triage_for, ->(user) { incoming.where(lead_user_id: user.id, routed_at: nil) }
  scope :with_status, ->(status) { status.present? ? where(status: status) : all }
  scope :in_folder, ->(folder) { where(folder: folder) }
  scope :unfiled, -> { where(folder_id: nil) }
  scope :sorted, ->(column, direction) {
    col = SORTABLE_COLUMNS.fetch(column.to_s, SORTABLE_COLUMNS[DEFAULT_SORT_COLUMN])
    dir = %w[asc desc].include?(direction.to_s) ? direction.to_s : DEFAULT_SORT_DIRECTION
    order(Arel.sql("#{col} #{dir}, documents.created_at #{dir}"))
  }

  # Callbacks
  before_validation :generate_reference_number, on: :create
  before_validation :clear_response_deadline_unless_expecting_response

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

  def awaiting_response_from?(user)
    expects_response? && addressee_type == "User" && addressee_id == user.id
  end

  def routed?
    routed_at.present?
  end

  def incoming?
    direction == "incoming"
  end

  def outgoing?
    direction == "outgoing"
  end

  def deadline_overdue?
    response_deadline.present? && Date.current >= response_deadline
  end

  def deadline_due_tomorrow?
    response_deadline.present? && Date.current == response_deadline - 1.day
  end

  def current_step
    workflow_steps.ordered.find_by(status: "pending")
  end

  def checked_out?
    checked_out_by_id.present?
  end

  def checked_out_by?(user)
    checked_out_by_id == user&.id
  end

  def locked_for?(user)
    checked_out? && !checked_out_by?(user)
  end

  def thread
    root.self_and_descendants.sort_by { |doc| [ doc.document_date, doc.created_at ] }
  end

  def root
    doc = self
    doc = doc.in_reply_to while doc.in_reply_to
    doc
  end

  def self_and_descendants
    [ self ] + replies.flat_map(&:self_and_descendants)
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

  def clear_response_deadline_unless_expecting_response
    self.response_deadline = nil unless expects_response?
  end

  def sender_belongs_to_entity
    return if entity.nil? || party_in_entity?(sender)

    errors.add(:sender, "must belong to the same entity")
  end

  def addressee_belongs_to_entity
    return if entity.nil? || party_in_entity?(addressee)

    errors.add(:addressee, "must belong to the same entity")
  end

  def department_belongs_to_entity
    return if entity.nil? || department.nil? || department.entity_id == entity_id

    errors.add(:department, "must belong to the same entity")
  end

  def in_reply_to_belongs_to_entity
    return if entity.nil? || in_reply_to.nil? || in_reply_to.entity_id == entity_id

    errors.add(:in_reply_to, "must belong to the same entity")
  end

  def folder_belongs_to_department
    return if folder.nil? || department.nil? || folder.department_id == department_id

    errors.add(:folder, "must belong to the same department")
  end

  def lead_user_belongs_to_entity
    return if entity.nil? || lead_user.nil? || EntityUser.active.exists?(entity_id: entity_id, user_id: lead_user_id)

    errors.add(:lead_user, "must belong to the same entity")
  end
end
