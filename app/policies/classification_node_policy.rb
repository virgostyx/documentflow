# frozen_string_literal: true

class ClassificationNodePolicy < ApplicationPolicy
  def index?
    entity_staff? || entity_guest?
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
    include EntityAccessible
  end
end
