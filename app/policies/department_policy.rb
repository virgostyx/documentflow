# frozen_string_literal: true

class DepartmentPolicy < ApplicationPolicy
  def index?
    entity_staff? || entity_guest?
  end

  def show?
    index?
  end

  def create?
    entity_owner? || entity_admin?
  end

  def update?
    entity_owner? || entity_admin?
  end

  def destroy?
    (entity_owner? || entity_admin?) && !record.is_default? && record.documents.none?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(entity: accessible_entities)
    end

    private

    def accessible_entities
      EntityUser.active.where(user: user).select(:entity_id)
    end
  end
end
