class AddSharedLinkRenewedAtToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :shared_link_renewed_at, :datetime
  end
end
