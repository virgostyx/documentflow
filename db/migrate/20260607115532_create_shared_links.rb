class CreateSharedLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :shared_links do |t|
      t.references :document, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :shared_links, :token, unique: true
  end
end
