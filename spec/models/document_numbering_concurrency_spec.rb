# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Document reference number concurrency", concurrency: true do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }

  def sign_concurrently(documents)
    errors = Queue.new

    threads = documents.map do |document|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { document.sign! }
      rescue StandardError => e
        errors << e
      end
    end
    threads.each(&:join)

    errors
  end

  it "assigns unique, gapless reference numbers when multiple documents are signed concurrently" do
    documents = 8.times.map { create(:document, :in_progress, entity: entity, department: department) }

    errors = sign_concurrently(documents)

    expect(errors).to be_empty, -> { Array.new(errors.size) { errors.pop }.map(&:full_message).join("\n\n") }

    sequences = documents.map { |document| ReferenceNumber.parse(document.reload.reference_number).sequence }
    expect(sequences.uniq.size).to eq(documents.size)
    expect(sequences.sort).to eq((1..documents.size).to_a)
  end

  it "keeps independent, gapless sequences per department under concurrent signing" do
    other_department = create(:department, entity: entity)
    documents = 4.times.map { create(:document, :in_progress, entity: entity, department: department) } +
                4.times.map { create(:document, :in_progress, entity: entity, department: other_department) }

    errors = sign_concurrently(documents)

    expect(errors).to be_empty, -> { Array.new(errors.size) { errors.pop }.map(&:full_message).join("\n\n") }

    [ department, other_department ].each do |dept|
      sequences = documents.select { |document| document.department_id == dept.id }
                            .map { |document| ReferenceNumber.parse(document.reload.reference_number).sequence }
      expect(sequences.sort).to eq((1..4).to_a)
    end
  end
end
