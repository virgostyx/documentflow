class AddInReplyToToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_reference :documents, :in_reply_to, null: true, foreign_key: { to_table: :documents }
  end
end
