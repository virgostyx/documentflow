# frozen_string_literal: true

class DocumentDismissal < ApplicationRecord
  belongs_to :document
  belongs_to :user

  validates :tab, inclusion: { in: %w[waiting info] }
end
