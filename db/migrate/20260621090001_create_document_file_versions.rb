class CreateDocumentFileVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :document_file_versions do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.text :comment

      t.timestamps
    end

    add_index :document_file_versions, %i[document_id version_number], unique: true
  end
end
