# frozen_string_literal: true

class FolderPolicy < ApplicationPolicy
  def create?
    department_accessible?
  end

  def update?
    department_accessible?
  end

  def destroy?
    department_accessible?
  end

  class Scope < ApplicationPolicy::Scope
    include DepartmentScoped
  end

  private

  def department_accessible?
    return false unless entity_staff? || entity_guest?
    return true if entity_owner? || entity_admin?

    entity_user.member_of?(record.department)
  end
end
