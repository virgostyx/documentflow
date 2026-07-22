# frozen_string_literal: true

class AddNullConstraintToEntitiesPrefix < ActiveRecord::Migration[8.1]
  class MigrationEntity < ActiveRecord::Base
    self.table_name = "entities"
  end

  def up
    backfill_prefixes
    change_column_null :entities, :prefix, false
  end

  def down
    change_column_null :entities, :prefix, true
  end

  private

  def backfill_prefixes
    used = MigrationEntity.where.not(prefix: nil).pluck(:prefix).to_set

    MigrationEntity.where(prefix: nil).find_each do |entity|
      source = entity.acronym.presence || entity.name
      entity.update_column(:prefix, unique_prefix(source, used))
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
