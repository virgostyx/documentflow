# frozen_string_literal: true

class DocumentPolicy < ApplicationPolicy
  def index?
    entity_staff? || entity_guest?
  end

  def create?
    entity_staff?
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
      scope.where(entity: accessible_entities)
    end

    private

    def accessible_entities
      EntityUser.active.where(user: user).select(:entity_id)
    end
  end
end
