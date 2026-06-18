# frozen_string_literal: true

namespace :departments do
  desc "Backfill a default Department per Entity and assign it to all existing Documents"
  task backfill: :environment do
    Entity.find_each do |entity|
      department = entity.departments.find_or_create_by!(name: "General") { |d| d.is_default = true }
      updated = entity.documents.where(department_id: nil).update_all(department_id: department.id)
      puts "Entity ##{entity.id} (#{entity.name}): #{updated} documents backfilled to '#{department.name}'"
    end
  end
end
