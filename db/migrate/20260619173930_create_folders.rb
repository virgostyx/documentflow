class CreateFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :folders do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :folders }
      t.string :name, null: false

      t.timestamps
    end

    add_index :folders, [ :department_id, :parent_id, :name ], unique: true, name: "index_folders_on_department_parent_name"
  end
end
