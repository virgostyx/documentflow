class CreateDocumentDismissals < ActiveRecord::Migration[8.1]
  def change
    create_table :document_dismissals do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :tab, null: false
      t.text :message

      t.timestamps
    end

    add_index :document_dismissals, [ :document_id, :user_id, :tab ], unique: true, name: "index_document_dismissals_unique"
  end
end
