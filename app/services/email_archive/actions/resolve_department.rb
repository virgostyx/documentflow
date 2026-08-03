# frozen_string_literal: true

module EmailArchive
  module Actions
    class ResolveDepartment < ApplicationAction
      expects :delivered_to
      promises :department, :entity

      executed do |ctx|
        department = Department.find_by(archive_ingestion_email: ctx.delivered_to)

        if department
          ctx.department = department
          ctx.entity = department.entity
        else
          fail_with!(ctx, "No department configured for archive address #{ctx.delivered_to}", :validation_error)
        end
      end
    end
  end
end
