# frozen_string_literal: true

class DocumentPolicy < ApplicationPolicy
  def index?
    entity_staff? || entity_guest?
  end

  def show?
    return false unless entity_staff? || entity_guest?
    return true if entity_owner? || entity_admin?

    entity_user.member_of?(record.department) || record.workflow_steps.exists?(actor: user)
  end

  def create?
    return false unless entity_staff?
    return true if entity_owner? || entity_admin?

    entity_user.departments.exists?
  end

  def update?
    return false if record.is_frozen?

    if record.draft?
      record.created_by == user || entity_admin? || entity_owner?
    elsif record.in_progress?
      record.current_step&.actor == user
    else
      false
    end
  end

  def destroy?
    entity_owner? || entity_admin?
  end

  def launch?
    record.draft? && (record.created_by == user || entity_admin? || entity_owner?)
  end

  def cancel?
    return false if record.finalized?

    record.created_by == user || entity_admin? || entity_owner?
  end

  def approve?
    record.current_step&.actor == user
  end

  def reject?
    record.current_step&.actor == user && record.current_step&.role != "RED"
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(entity_id: unrestricted_entity_ids)
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
