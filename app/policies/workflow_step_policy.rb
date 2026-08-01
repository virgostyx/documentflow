# frozen_string_literal: true

class WorkflowStepPolicy < ApplicationPolicy
  def create?
    manageable?
  end

  def update?
    manageable?
  end

  def destroy?
    manageable?
  end

  def move_up?
    manageable?
  end

  def move_down?
    manageable?
  end

  def apply_template?
    manageable?
  end

  def reorder?
    manageable?
  end

  def reassign?
    return false unless record.pending?
    return false if record.document.finalized? || record.document.cancelled?

    entity_owner? || entity_admin? || record.document.created_by == user
  end

  private

  def entity
    record.document&.entity
  end

  def manageable?
    record.document.draft? && DocumentPolicy.new(user, record.document).update?
  end
end
