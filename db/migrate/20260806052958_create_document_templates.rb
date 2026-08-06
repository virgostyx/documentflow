# frozen_string_literal: true

class CreateDocumentTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :document_templates do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :department, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :circuit_template, foreign_key: true
      t.string :name, null: false
      t.text :subject_template, null: false
      t.text :body_template, null: false
      t.string :default_sender_type
      t.bigint :default_sender_id
      t.string :default_addressee_type
      t.bigint :default_addressee_id

      t.timestamps
    end

    add_index :document_templates, [ :entity_id, :name ], unique: true
    add_index :document_templates, [ :default_sender_type, :default_sender_id ]
    add_index :document_templates, [ :default_addressee_type, :default_addressee_id ]
  end
end
