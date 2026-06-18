# frozen_string_literal: true

class CreateEntityUserDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :entity_user_departments do |t|
      t.references :entity_user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.boolean :primary, null: false, default: false

      t.timestamps
    end

    add_index :entity_user_departments, [ :entity_user_id, :department_id ], unique: true
    add_index :entity_user_departments, :entity_user_id, unique: true, where: "\"primary\"",
              name: "index_one_primary_department_per_entity_user"
  end
end
