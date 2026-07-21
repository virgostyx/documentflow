# frozen_string_literal: true

class AddPrefixToDepartments < ActiveRecord::Migration[8.1]
  def change
    add_column :departments, :prefix, :string
    add_index :departments, [ :entity_id, :prefix ], unique: true
  end
end
