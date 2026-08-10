# frozen_string_literal: true

# Abstract base for templates that are shared entity-wide by default but can
# optionally be restricted to a single department. Not resolved directly by
# Pundit — DocumentTemplatePolicy and EmailTemplatePolicy inherit from it.
class DepartmentScopedTemplatePolicy < ApplicationPolicy
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
    include DepartmentScoped

    # Unlike DepartmentScoped's default, restricted (member/guest) users can also
    # see entity-wide templates (department_id: nil), not just their own department's.
    def resolve
      super.or(scope.where(entity_id: restricted_entity_ids, department_id: nil))
    end
  end
end
