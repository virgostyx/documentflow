# frozen_string_literal: true

module Templates
  # Single source of truth for the {{tag}} placeholder syntax shared by
  # DocumentTemplate (subject + docx body) and EmailTemplate (body).
  module TagScanner
    TAG_PATTERN = /\{\{(\w+)\}\}/

    def self.tags_in(text)
      text.to_s.scan(TAG_PATTERN).flatten.uniq
    end
  end
end
