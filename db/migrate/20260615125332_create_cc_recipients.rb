# frozen_string_literal: true

class CreateCcRecipients < ActiveRecord::Migration[8.1]
  def change
    create_table :cc_recipients do |t|
      t.references :document, null: false, foreign_key: true
      t.string :party_type, null: false
      t.bigint :party_id, null: false

      t.timestamps
    end

    add_index :cc_recipients, [ :document_id, :party_type, :party_id ], unique: true, name: "index_cc_recipients_unique"
    add_index :cc_recipients, [ :party_type, :party_id ]
  end
end
