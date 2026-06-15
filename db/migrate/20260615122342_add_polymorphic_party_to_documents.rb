class AddPolymorphicPartyToDocuments < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :documents, column: :sender_id
    remove_foreign_key :documents, column: :addressee_id
    remove_index :documents, :sender_id
    remove_index :documents, :addressee_id

    add_column :documents, :sender_type, :string
    add_column :documents, :addressee_type, :string

    Document.unscoped.update_all(sender_type: "Contact", addressee_type: "Contact")

    change_column_null :documents, :sender_type, false
    change_column_null :documents, :addressee_type, false

    add_index :documents, [ :sender_type, :sender_id ]
    add_index :documents, [ :addressee_type, :addressee_id ]
  end

  def down
    remove_index :documents, [ :sender_type, :sender_id ]
    remove_index :documents, [ :addressee_type, :addressee_id ]

    remove_column :documents, :sender_type
    remove_column :documents, :addressee_type

    add_index :documents, :sender_id
    add_index :documents, :addressee_id
    add_foreign_key :documents, :contacts, column: :sender_id
    add_foreign_key :documents, :contacts, column: :addressee_id
  end
end
