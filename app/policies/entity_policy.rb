# frozen_string_literal: true

class EntityPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def show?
    entity_owner? || entity_admin? || entity_member? || entity_guest?
  end

  def update?
    entity_owner? || entity_admin?
  end

  def destroy?
    entity_owner?
  end

  def manage_members?
    entity_owner? || entity_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:entity_users).merge(EntityUser.active.where(user: user))
    end
  end
end
