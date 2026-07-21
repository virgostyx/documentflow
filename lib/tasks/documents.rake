# frozen_string_literal: true

namespace :documents do
  desc "Regenerate all reference_number values as PREFIX(YYYY)#####, scoped per department and year. Set DRY_RUN=1 to preview without writing."
  task regenerate_reference_numbers: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    puts "*** DRY RUN — no changes will be written ***" if dry_run

    Department.find_each do |department|
      counters = Hash.new(0)

      department.documents.order(:document_date, :created_at).each do |document|
        year = document.document_date&.year || document.created_at.year
        counters[year] += 1
        new_reference = ReferenceNumber.new(prefix: department.prefix, year: year, sequence: counters[year]).to_s

        if dry_run
          puts "Document ##{document.id}: #{document.reference_number} -> #{new_reference}"
        else
          document.update_column(:reference_number, new_reference)
        end
      end
    end

    puts "Done." unless dry_run
  end
end
