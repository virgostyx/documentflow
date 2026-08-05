class AddDispatchMessageToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :dispatch_message, :text
  end
end
