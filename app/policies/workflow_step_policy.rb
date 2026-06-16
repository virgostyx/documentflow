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

  private

  def entity
    record.document&.entity
  end

  def manageable?
    record.document.draft? && DocumentPolicy.new(user, record.document).update?
  end
end
