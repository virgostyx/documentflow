class AddAcronymToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :acronym, :string
  end
end
