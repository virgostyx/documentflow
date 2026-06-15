# frozen_string_literal: true

class CreateCircuitTemplateSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :circuit_template_steps do |t|
      t.references :circuit_template, null: false, foreign_key: true
      t.string :role, null: false
      t.integer :order, null: false
      t.bigint :actor_id
      t.boolean :is_parallel, default: false, null: false
      t.integer :parallel_group

      t.timestamps
    end

    add_index :circuit_template_steps, [ :circuit_template_id, :order ], unique: true
    add_foreign_key :circuit_template_steps, :users, column: :actor_id
  end
end
