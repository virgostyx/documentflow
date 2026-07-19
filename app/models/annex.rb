# frozen_string_literal: true

class Annex < ApplicationRecord
  belongs_to :document
  has_one_attached :file
  has_many :document_file_versions, dependent: :destroy
end
