class CreateClassificationNodes < ActiveRecord::Migration[8.1]
  def change
    create_table :classification_nodes do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :classification_nodes }
      t.string :code, null: false
      t.string :name, null: false
      t.integer :depth, null: false

      t.timestamps
    end

    add_index :classification_nodes, [ :entity_id, :code ], unique: true, name: "index_classification_nodes_on_entity_and_code"
    add_index :classification_nodes, [ :entity_id, :parent_id, :name ], unique: true, name: "index_classification_nodes_on_entity_parent_name"
  end
end
