# frozen_string_literal: true

class CircuitTemplatePolicy < ApplicationPolicy
  def index?
    entity_owner? || entity_admin?
  end

  def create?
    entity_owner? || entity_admin?
  end

  def update?
    entity_owner? || entity_admin?
  end

  def destroy?
    entity_owner? || entity_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(entity: accessible_entities)
    end

    private

    def accessible_entities
      EntityUser.active.where(user: user, role: %w[owner admin]).select(:entity_id)
    end
  end
end
