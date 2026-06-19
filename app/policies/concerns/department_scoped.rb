# frozen_string_literal: true

# Shared resolution logic for any Pundit::Scope whose records are scoped to an
# Entity directly (owner/admin: unrestricted) or to a Department (member/guest:
# restricted to their assigned departments).
module DepartmentScoped
  def resolve
    scope.where(entity_id: unrestricted_entity_ids)
         .or(scope.where(entity_id: restricted_entity_ids, department_id: accessible_department_ids))
  end

  private

  def active_entity_users
    EntityUser.active.where(user: user)
  end

  def unrestricted_entity_ids
    active_entity_users.where(role: %w[owner admin]).select(:entity_id)
  end

  def restricted_entity_ids
    active_entity_users.where(role: %w[member guest]).select(:entity_id)
  end

  def accessible_department_ids
    EntityUserDepartment.where(entity_user_id: active_entity_users.where(role: %w[member guest]).select(:id))
                         .select(:department_id)
  end
end
