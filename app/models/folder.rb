# frozen_string_literal: true

class Folder < ApplicationRecord
  belongs_to :entity
  belongs_to :department
  belongs_to :parent, class_name: "Folder", optional: true
  has_many :children, class_name: "Folder", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :documents, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: [ :department_id, :parent_id ] }
  validate :entity_matches_department
  validate :parent_belongs_to_same_department
  validate :parent_is_a_root_folder

  def root?
    parent_id.nil?
  end

  private

  def entity_matches_department
    return if department.nil? || entity_id == department.entity_id

    errors.add(:entity, "must match the department's entity")
  end

  def parent_belongs_to_same_department
    return if parent.nil? || parent.department_id == department_id

    errors.add(:parent, "must belong to the same department")
  end

  def parent_is_a_root_folder
    return if parent.nil? || parent.parent_id.nil?

    errors.add(:parent, "cannot itself be a subfolder")
  end
end
