# frozen_string_literal: true

class RemoveBodyTemplateFromDocumentTemplates < ActiveRecord::Migration[8.1]
  def change
    remove_column :document_templates, :body_template, :text, null: false
  end
end
