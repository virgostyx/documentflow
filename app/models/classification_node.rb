# frozen_string_literal: true

class ClassificationNode < ApplicationRecord
  MAX_DEPTH = 4
  CODE_FORMAT = /\A[1-9]\d*(\.[1-9]\d*){0,3}\z/

  belongs_to :entity
  belongs_to :parent, class_name: "ClassificationNode", optional: true
  has_many :children, class_name: "ClassificationNode", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :documents, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: [ :entity_id, :parent_id ] }
  validates :code, presence: true, format: { with: CODE_FORMAT, message: "must be digits separated by dots (e.g. 1.2.3)" },
                    uniqueness: { scope: :entity_id }
  validate :entity_matches_parent
  validate :code_matches_parent
  validate :depth_within_bounds

  before_validation :compute_depth

  def root?
    parent_id.nil?
  end

  def self.sort_by_code(nodes)
    nodes.sort_by { |node| node.code.split(".").map(&:to_i) }
  end

  private

  def compute_depth
    self.depth = code.to_s.split(".").size if code.present?
  end

  def entity_matches_parent
    return if parent.nil? || entity_id == parent.entity_id

    errors.add(:entity, "must match the parent's entity")
  end

  def code_matches_parent
    return if code.blank? || !code.match?(CODE_FORMAT)

    segments = code.split(".")

    if parent.nil?
      errors.add(:code, "must be a single segment for a root node") unless segments.size == 1
    else
      expected_prefix = parent.code.split(".")
      errors.add(:code, "must extend the parent's code (#{parent.code}.N)") unless segments[0...-1] == expected_prefix
    end
  end

  def depth_within_bounds
    return if parent.nil?

    errors.add(:parent, "cannot have children beyond depth #{MAX_DEPTH}") if parent.depth >= MAX_DEPTH
  end
end
