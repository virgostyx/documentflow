# frozen_string_literal: true

class AddPrefixToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :prefix, :string
    add_index :entities, :prefix, unique: true
  end
end
