# frozen_string_literal: true

class DocumentFileVersion < ApplicationRecord
  belongs_to :document
  belongs_to :user
  belongs_to :annex, optional: true
  has_one_attached :file

  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 },
                              uniqueness: { scope: %i[document_id annex_id] }

  scope :ordered, -> { order(:version_number) }

  def self.next_version_number(document)
    document.document_file_versions.maximum(:version_number).to_i + 1
  end
end
