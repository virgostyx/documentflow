# frozen_string_literal: true

class SharedLinkPolicy < ApplicationPolicy
  def create?
    record.document.finalized? && entity_staff?
  end

  def destroy?
    entity_staff?
  end

  private

  def entity
    record.document&.entity
  end
end
