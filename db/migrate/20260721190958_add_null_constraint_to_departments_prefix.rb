# frozen_string_literal: true

class AddNullConstraintToDepartmentsPrefix < ActiveRecord::Migration[8.1]
  class MigrationDepartment < ActiveRecord::Base
    self.table_name = "departments"
  end

  class MigrationEntity < ActiveRecord::Base
    self.table_name = "entities"
  end

  def up
    backfill_prefixes
    change_column_null :departments, :prefix, false
  end

  def down
    change_column_null :departments, :prefix, true
  end

  private

  def backfill_prefixes
    MigrationDepartment.where(prefix: nil).group_by(&:entity_id).each do |entity_id, departments|
      used = MigrationDepartment.where(entity_id: entity_id).where.not(prefix: nil).pluck(:prefix).to_set
      entity = MigrationEntity.find(entity_id)

      departments.each do |department|
        source = department.is_default? ? "#{entity.prefix}GEN"[0, 8] : department.name
        department.update_column(:prefix, unique_prefix(source, used))
      end
    end
  end

  def unique_prefix(source, used)
    base = source.to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 8]
    base = "PREFIX" if base.blank?

    candidate = base
    suffix = 1
    while used.include?(candidate)
      suffix_str = suffix.to_s
      candidate = "#{base[0, 8 - suffix_str.length]}#{suffix_str}"
      suffix += 1
    end

    used << candidate
    candidate
  end
end
