# frozen_string_literal: true

class AddMultiRecipientToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :multi_recipient, :boolean, null: false, default: false
  end
end
