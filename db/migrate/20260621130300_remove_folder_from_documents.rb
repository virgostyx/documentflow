class RemoveFolderFromDocuments < ActiveRecord::Migration[8.1]
  def change
    remove_reference :documents, :folder, foreign_key: true
  end
end
