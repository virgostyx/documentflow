class AddTemporaryNumberToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :temporary_number, :string
    add_index :documents, :temporary_number, unique: true

    change_column_null :documents, :reference_number, true
  end
end
