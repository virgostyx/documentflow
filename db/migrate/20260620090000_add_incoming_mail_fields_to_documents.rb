class AddIncomingMailFieldsToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :direction, :string, null: false, default: "outgoing"
    add_reference :documents, :lead_user, foreign_key: { to_table: :users }
    add_column :documents, :routing_message, :text
    add_column :documents, :routed_at, :datetime
  end
end
