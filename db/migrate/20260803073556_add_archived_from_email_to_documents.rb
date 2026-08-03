class AddArchivedFromEmailToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :archived_from_email, :boolean, default: false, null: false
  end
end
