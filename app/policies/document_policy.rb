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

  def apply_distribution_list?
    record.draft? && update?
  end

  def launch?
    record.draft? && (record.created_by == user || entity_admin? || entity_owner?)
  end

  def cancel?
    return false if record.finalized?

    record.created_by == user || entity_admin? || entity_owner?
  end

  def approve?
    (record.in_progress? || record.signed?) && record.current_step&.actor == user
  end

  def reject?
    (record.in_progress? || record.signed?) && record.current_step&.actor == user && record.current_step&.role != "RED"
  end

  def classify?
    show?
  end

  def check_out?
    return false if record.is_frozen? || record.checked_out?

    update?
  end

  def check_in?
    record.checked_out_by?(user) && update?
  end

  def cancel_check_out?
    return false unless record.checked_out?

    record.checked_out_by?(user) || entity_admin? || entity_owner?
  end

  def route?
    return false if record.outgoing? || record.routed?

    record.lead_user == user || entity_admin? || entity_owner?
  end

  class Scope < ApplicationPolicy::Scope
    include DepartmentScoped
  end
end
