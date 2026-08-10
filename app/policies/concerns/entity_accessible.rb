# frozen_string_literal: true

# Shared resolution logic for any Pundit::Scope whose records are scoped to an
# Entity the user has any active membership in, regardless of role or department.
module EntityAccessible
  def resolve
    scope.where(entity: accessible_entities)
  end

  private

  def accessible_entities
    EntityUser.active.where(user: user).select(:entity_id)
  end
end
