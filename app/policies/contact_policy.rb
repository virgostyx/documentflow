# frozen_string_literal: true

class ContactPolicy < ApplicationPolicy
  def index?
    entity_staff? || entity_guest?
  end

  def create?
    entity_staff?
  end

  def update?
    entity_staff?
  end

  def destroy?
    entity_staff?
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
