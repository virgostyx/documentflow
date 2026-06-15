# frozen_string_literal: true

class CreateCircuitTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :circuit_templates do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :circuit_templates, [ :entity_id, :name ], unique: true
  end
end
