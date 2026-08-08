# frozen_string_literal: true

class CreateEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :email_templates do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :department, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :body_template, null: false

      t.timestamps
    end

    add_index :email_templates, [ :entity_id, :name ], unique: true
  end
end
