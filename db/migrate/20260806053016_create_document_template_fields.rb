# frozen_string_literal: true

class CreateDocumentTemplateFields < ActiveRecord::Migration[8.1]
  def change
    create_table :document_template_fields do |t|
      t.references :document_template, null: false, foreign_key: true
      t.string :tag_name, null: false
      t.string :label, null: false
      t.string :field_type, null: false, default: "text"
      t.jsonb :options, default: []
      t.boolean :required, default: true, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :document_template_fields, [ :document_template_id, :tag_name ], unique: true
    add_index :document_template_fields, [ :document_template_id, :position ], unique: true
  end
end
