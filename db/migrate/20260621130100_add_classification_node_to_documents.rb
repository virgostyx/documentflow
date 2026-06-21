class AddClassificationNodeToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_reference :documents, :classification_node, foreign_key: true
  end
end
