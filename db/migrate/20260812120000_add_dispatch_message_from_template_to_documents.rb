# frozen_string_literal: true

class AddDispatchMessageFromTemplateToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :dispatch_message_from_template, :boolean, default: false, null: false
  end
end
