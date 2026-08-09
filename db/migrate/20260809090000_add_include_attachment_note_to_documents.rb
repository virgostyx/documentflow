# frozen_string_literal: true

class AddIncludeAttachmentNoteToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :include_attachment_note, :boolean, default: true, null: false
  end
end
