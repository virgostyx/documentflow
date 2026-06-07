class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :company
      t.string :phone

      t.timestamps
    end

    add_index :contacts, [ :entity_id, :email ], unique: true
  end
end
