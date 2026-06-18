# frozen_string_literal: true

class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end

    add_index :departments, [ :entity_id, :name ], unique: true
  end
end
