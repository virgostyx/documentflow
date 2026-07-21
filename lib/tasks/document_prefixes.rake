# frozen_string_literal: true

namespace :document_prefixes do
  desc "Backfill a placeholder prefix for every Entity and Department that doesn't have one yet"
  task backfill: :environment do
    used_entity_prefixes = Entity.where.not(prefix: nil).pluck(:prefix).to_set

    Entity.where(prefix: nil).find_each do |entity|
      source = entity.acronym.presence || entity.name
      entity.update_column(:prefix, unique_prefix(source, used_entity_prefixes))
      puts "Entity ##{entity.id} (#{entity.name}): prefix set to '#{entity.prefix}'"
    end

    Department.includes(:entity).find_each do |department|
      next if department.prefix.present?

      used_department_prefixes = Department.where(entity_id: department.entity_id).where.not(prefix: nil).pluck(:prefix).to_set
      prefix = department.default? ? "#{department.entity.prefix}GEN"[0, 8] : department.name
      department.update_column(:prefix, unique_prefix(prefix, used_department_prefixes))
      puts "Department ##{department.id} (#{department.name}): prefix set to '#{department.prefix}'"
    end
  end

  def unique_prefix(source, used_prefixes)
    base = source.to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 8]
    base = "PREFIX" if base.blank?

    candidate = base
    suffix = 1
    while used_prefixes.include?(candidate)
      suffix_str = suffix.to_s
      candidate = "#{base[0, 8 - suffix_str.length]}#{suffix_str}"
      suffix += 1
    end

    used_prefixes << candidate
    candidate
  end
end
