# frozen_string_literal: true

class EntityUserDepartment < ApplicationRecord
  belongs_to :entity_user
  belongs_to :department

  validates :department_id, uniqueness: { scope: :entity_user_id }
  validate :department_belongs_to_entity_users_entity
  validate :only_one_primary_per_entity_user, if: :primary?

  private

  def department_belongs_to_entity_users_entity
    return if department.nil? || entity_user.nil?
    return if department.entity_id == entity_user.entity_id

    errors.add(:department, "must belong to the same entity as the member")
  end

  def only_one_primary_per_entity_user
    existing = EntityUserDepartment.where(entity_user_id: entity_user_id, primary: true)
    existing = existing.where.not(id: id) if persisted?

    errors.add(:primary, "another department is already marked as primary for this member") if existing.exists?
  end
end
