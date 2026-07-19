class BackfillAnnexRecordsFromAttachments < ActiveRecord::Migration[8.1]
  class MigrationAnnex < ActiveRecord::Base
    self.table_name = "annexes"
  end

  def up
    ActiveStorage::Attachment.where(record_type: "Document", name: "annexes").find_each do |attachment|
      annex = MigrationAnnex.create!(
        document_id: attachment.record_id,
        created_at: attachment.created_at,
        updated_at: attachment.created_at
      )

      # update_columns bypasses the polymorphic `record` association callbacks, which would
      # otherwise try to constantize "Annex" before the model class exists in this migration.
      attachment.update_columns(record_type: "Annex", record_id: annex.id, name: "file")
    end
  end

  def down
    ActiveStorage::Attachment.where(record_type: "Annex", name: "file").find_each do |attachment|
      annex = MigrationAnnex.find(attachment.record_id)

      attachment.update_columns(record_type: "Document", record_id: annex.document_id, name: "annexes")
    end

    MigrationAnnex.delete_all
  end
end
