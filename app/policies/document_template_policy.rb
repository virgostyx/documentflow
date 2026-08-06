# frozen_string_literal: true

class DocumentTemplatePolicy < ApplicationPolicy
  def index?
    entity_staff? || entity_guest?
  end

  def show?
    return false unless entity_staff? || entity_guest?
    return true if entity_owner? || entity_admin?
    return true if record.department_id.nil?

    entity_user.member_of?(record.department)
  end

  def create?
    entity_staff?
  end

  def update?
    record.created_by == user || entity_owner? || entity_admin?
  end

  def destroy?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(entity_id: unrestricted_entity_ids)
           .or(scope.where(entity_id: restricted_entity_ids, department_id: nil))
           .or(scope.where(entity_id: restricted_entity_ids, department_id: accessible_department_ids))
    end

    private

    def active_entity_users
      EntityUser.active.where(user: user)
    end

    def unrestricted_entity_ids
      active_entity_users.where(role: %w[owner admin]).select(:entity_id)
    end

    def restricted_entity_ids
      active_entity_users.where(role: %w[member guest]).select(:entity_id)
    end

    def accessible_department_ids
      EntityUserDepartment.where(entity_user_id: active_entity_users.where(role: %w[member guest]).select(:id))
                           .select(:department_id)
    end
  end
end
