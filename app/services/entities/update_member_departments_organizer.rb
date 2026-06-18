# frozen_string_literal: true

module Entities
  class UpdateMemberDepartmentsOrganizer < ApplicationService
    workflow_steps Actions::ValidateAtLeastOneDepartment,
                   Actions::ReplaceMemberDepartments
  end
end
