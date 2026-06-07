class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :sender, null: false, foreign_key: { to_table: :contacts }
      t.references :addressee, null: false, foreign_key: { to_table: :contacts }
      t.string :reference_number, null: false
      t.string :subject, null: false
      t.date :document_date, null: false
      t.string :status, default: "draft", null: false
      t.boolean :is_frozen, default: false, null: false

      t.timestamps
    end

    add_index :documents, [ :entity_id, :reference_number ], unique: true
    add_index :documents, :status
  end
end
