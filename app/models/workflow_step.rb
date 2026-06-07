# frozen_string_literal: true

class WorkflowStep < ApplicationRecord
  ROLES = %w[RED VISA SIGN EXP].freeze
  STATUSES = %w[pending approved rejected skipped].freeze

  # Associations
  belongs_to :document
  belongs_to :actor, class_name: "User", optional: true

  # Validations
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :order, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :skipped, -> { where(status: "skipped") }
  scope :ordered, -> { order(:order) }

  # Methods
  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def skipped?
    status == "skipped"
  end

  def red?
    role == "RED"
  end

  def visa?
    role == "VISA"
  end

  def sign?
    role == "SIGN"
  end

  def exp?
    role == "EXP"
  end

  def parallel?
    is_parallel
  end
end
