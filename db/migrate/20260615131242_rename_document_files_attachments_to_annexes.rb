# frozen_string_literal: true

class RenameDocumentFilesAttachmentsToAnnexes < ActiveRecord::Migration[8.1]
  def up
    ActiveStorage::Attachment.where(record_type: "Document", name: "files").update_all(name: "annexes")
  end

  def down
    ActiveStorage::Attachment.where(record_type: "Document", name: "annexes").update_all(name: "files")
  end
end
