class AddWopiLockIdToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :wopi_lock_id, :string
  end
end
