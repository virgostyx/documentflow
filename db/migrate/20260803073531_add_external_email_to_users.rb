class AddExternalEmailToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :external_email, :string
    add_index :users, :external_email, unique: true
  end
end
