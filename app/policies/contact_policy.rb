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
    include EntityAccessible
  end
end
