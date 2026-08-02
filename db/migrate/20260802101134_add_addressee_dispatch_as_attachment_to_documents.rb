class AddAddresseeDispatchAsAttachmentToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :addressee_dispatch_as_attachment, :boolean, default: false, null: false
  end
end
