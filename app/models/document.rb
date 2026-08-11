# frozen_string_literal: true

class Document < ApplicationRecord
  include AASM
  include PartyAssignable
  include EntityScopedAssociations

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
  belongs_to :classification_node, optional: true
  belongs_to :lead_user, class_name: "User", optional: true
  belongs_to :checked_out_by, class_name: "User", optional: true
  has_many :replies, class_name: "Document", foreign_key: :in_reply_to_id, inverse_of: :in_reply_to, dependent: :nullify
  has_many :workflow_steps, dependent: :destroy
  has_many :shared_links, dependent: :destroy
  has_many :cc_recipients, dependent: :destroy
  has_many :audit_logs, as: :auditable, dependent: :nullify
  has_many :document_file_versions, dependent: :destroy
  has_one_attached :main_file
  has_many :annexes, -> { order(:id) }, dependent: :destroy

  party_assignable :sender, :addressee

  # Not persisted; only used to redisplay the incoming mail routing form after a validation failure.
  attr_accessor :action_user_id, :info_user_ids

  # Not persisted; carries a chosen distribution list through the new -> create
  # request so its remaining members can be added as CC recipients on save.
  attr_accessor :distribution_list_id

  # Validations
  validates :subject, presence: true, length: { maximum: 255 }
  validates :document_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validate :sender_belongs_to_entity
  validate :addressee_belongs_to_entity
  validates_entity_scoped :department, :in_reply_to
  validate :classification_node_belongs_to_entity
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
    replied_document_ids = Document.settled
                                    .where(created_by_id: user.id)
                                    .where.not(in_reply_to_id: nil)
                                    .select(:in_reply_to_id)

    where(addressee_type: "User", addressee_id: user.id, expects_response: true)
      .where.not(id: replied_document_ids)
  }
  scope :pending_for, ->(user) {
    joins(:workflow_steps)
      .where(workflow_steps: { status: "pending", actor_id: user.id })
      .where(
        "workflow_steps.\"order\" = (SELECT MIN(ws2.\"order\") FROM workflow_steps ws2 " \
        "WHERE ws2.document_id = documents.id AND ws2.status = 'pending')"
      )
      .distinct
  }
  scope :waiting_for, ->(user) {
    replied_document_ids = Document.settled.where.not(in_reply_to_id: nil).select(:in_reply_to_id)

    where(
      "(documents.direction = 'outgoing' AND documents.created_by_id = :user_id) " \
      "OR (documents.direction = 'incoming' AND documents.lead_user_id = :user_id)",
      user_id: user.id
    ).where(expects_response: true).where.not(id: replied_document_ids)
  }
  scope :info_for, ->(user) {
    left_joins(:cc_recipients).where(
      "(" \
        "(documents.addressee_type = 'User' AND documents.addressee_id = :user_id AND documents.expects_response = false) " \
        "OR (documents.direction = 'outgoing' AND documents.created_by_id = :user_id AND documents.expects_response = false) " \
        "OR (documents.direction = 'incoming' AND documents.lead_user_id = :user_id AND documents.expects_response = false) " \
        "OR (cc_recipients.party_type = 'User' AND cc_recipients.party_id = :user_id)" \
      ")",
      user_id: user.id
    ).distinct
  }
  scope :incoming, -> { where(direction: "incoming") }
  scope :outgoing, -> { where(direction: "outgoing") }
  scope :pending_triage_for, ->(user) { incoming.where(lead_user_id: user.id, routed_at: nil) }
  scope :with_status, ->(status) { status.present? ? where(status: status) : all }
  scope :finalized, -> { where(status: "finalized") }
  scope :not_finalized, -> { where.not(status: "finalized") }
  # Incoming documents never leave AASM draft — `finalized` can never test
  # "released into circulation" for them; `routed_at` is their equivalent signal.
  scope :settled, -> {
    where(
      "(documents.direction = 'outgoing' AND documents.status = 'finalized') " \
      "OR (documents.direction = 'incoming' AND documents.routed_at IS NOT NULL)"
    )
  }
  scope :repliable_by, ->(sender) {
    outgoing.settled
            .where(addressee_type: sender.class.name, addressee_id: sender.id, expects_response: true)
            .where.not(id: Document.settled.where.not(in_reply_to_id: nil).select(:in_reply_to_id))
  }
  scope :in_classification_node, ->(node) { where(classification_node: node) }
  scope :unclassified, -> { where(classification_node_id: nil) }
  scope :sorted, ->(column, direction) {
    col = SORTABLE_COLUMNS.fetch(column.to_s, SORTABLE_COLUMNS[DEFAULT_SORT_COLUMN])
    dir = %w[asc desc].include?(direction.to_s) ? direction.to_s : DEFAULT_SORT_DIRECTION
    order(Arel.sql("#{col} #{dir}, documents.created_at #{dir}"))
  }

  # Callbacks
  #
  # Outgoing documents only get a provisional "temporary_number" at creation;
  # their definitive reference_number is assigned when the SIGN workflow step
  # is approved (see #assign_reference_number). Incoming mail does not go
  # through the sign/finalize workflow at all, so it keeps the legacy
  # behavior of getting its reference_number immediately. Email-archived
  # outgoing documents (archived_from_email) are also created already
  # "finalized" with no workflow_steps, so they need the same treatment.
  before_validation :generate_reference_number, on: :create, if: -> { incoming? || archived_from_email? }
  after_create :assign_temporary_number, unless: -> { incoming? || archived_from_email? }
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
      transitions from: :in_progress, to: :signed, after: [ :freeze_document, :assign_reference_number ]
    end

    event :finalize do
      transitions from: :signed, to: :finalized
    end

    event :cancel do
      transitions from: [ :draft, :in_progress, :signed ], to: :cancelled
    end
  end

  # Methods
  def frozen?
    is_frozen
  end

  # The number to show to users: the definitive reference_number once
  # assigned (at signature), otherwise the provisional temporary_number.
  def display_number
    reference_number.presence || temporary_number
  end

  def any_external_recipients?
    addressee.external? || cc_recipients.any? { |cc| cc.party.external? }
  end

  def active_shared_link
    shared_links.active.first || shared_links.create!
  end

  def claim_shared_link_renewal!
    self.class.where(id: id, shared_link_renewed_at: nil).update_all(shared_link_renewed_at: Time.current) == 1
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
    return unless entity && department

    year = document_date&.year || Date.current.year
    self.reference_number = next_reference_number(year: year)
  end

  # Assigns the definitive reference_number at the moment the document is
  # signed (SIGN workflow step approved). Scoped per department and per the
  # actual signature year (not document_date). A row lock on the department
  # serializes concurrent signatures within the same department/year so two
  # documents can never be assigned the same number.
  def assign_reference_number
    return if reference_number.present?
    return unless entity && department

    department.with_lock do
      update_column(:reference_number, next_reference_number(year: Date.current.year))
    end
  end

  def next_reference_number(year:)
    prefix = department.prefix.presence || entity.prefix
    last = department.documents.where("reference_number LIKE ?", "#{prefix}(#{year})%").maximum(:reference_number)
    reference = last ? ReferenceNumber.parse(last).next : ReferenceNumber.first_for(prefix: prefix, year: year)
    reference.to_s
  end

  def assign_temporary_number
    update_column(:temporary_number, "PROV-#{id}")
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

  def classification_node_belongs_to_entity
    return if classification_node.nil? || classification_node.entity_id == entity_id

    errors.add(:classification_node, "must belong to the same entity")
  end

  def lead_user_belongs_to_entity
    return if entity.nil? || lead_user.nil? || EntityUser.active.exists?(entity_id: entity_id, user_id: lead_user_id)

    errors.add(:lead_user, "must belong to the same entity")
  end
end
