class CreateEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :entities do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :status, default: "active", null: false

      t.timestamps
    end

    add_index :entities, :name, unique: true
    add_index :entities, :code, unique: true
    add_index :entities, :status
  end
end
