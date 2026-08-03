class AddArchiveIngestionEmailToDepartments < ActiveRecord::Migration[8.1]
  def change
    add_column :departments, :archive_ingestion_email, :string
    add_index :departments, :archive_ingestion_email, unique: true
  end
end
