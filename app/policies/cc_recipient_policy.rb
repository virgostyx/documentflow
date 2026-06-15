# frozen_string_literal: true

class CcRecipientPolicy < ApplicationPolicy
  def create?
    document_update?
  end

  def destroy?
    document_update?
  end

  private

  def entity
    record.document&.entity
  end

  def document_update?
    DocumentPolicy.new(user, record.document).update?
  end
end
