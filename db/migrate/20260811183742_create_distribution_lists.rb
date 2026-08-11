class CreateDistributionLists < ActiveRecord::Migration[8.1]
  def change
    create_table :distribution_lists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :distribution_lists, [ :user_id, :name ], unique: true
  end
end
