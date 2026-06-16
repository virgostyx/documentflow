class AddInternalToContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :contacts, :internal, :boolean, null: false, default: false
  end
end
