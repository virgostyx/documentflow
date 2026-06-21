class AddCheckoutToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_reference :documents, :checked_out_by, foreign_key: { to_table: :users }
    add_column :documents, :checked_out_at, :datetime
  end
end
