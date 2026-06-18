class AddExpectsResponseToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :expects_response, :boolean, default: false, null: false
  end
end
