class AddDispatchAsAttachmentToCcRecipients < ActiveRecord::Migration[8.1]
  def change
    add_column :cc_recipients, :dispatch_as_attachment, :boolean, default: false, null: false
  end
end
