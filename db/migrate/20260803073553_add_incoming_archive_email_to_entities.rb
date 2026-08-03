class AddIncomingArchiveEmailToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :incoming_archive_email, :string
    add_index :entities, :incoming_archive_email, unique: true
  end
end
