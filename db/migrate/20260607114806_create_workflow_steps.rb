class CreateWorkflowSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_steps do |t|
      t.references :document, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :role, null: false
      t.integer :order, null: false
      t.string :status, default: "pending", null: false
      t.boolean :is_parallel, default: false, null: false
      t.integer :parallel_group
      t.text :comment

      t.timestamps
    end

    add_index :workflow_steps, [ :document_id, :order ], unique: true
    add_index :workflow_steps, :role
    add_index :workflow_steps, :status
  end
end
