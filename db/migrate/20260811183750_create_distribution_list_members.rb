class CreateDistributionListMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :distribution_list_members do |t|
      t.references :distribution_list, null: false, foreign_key: true
      t.string :party_type, null: false
      t.bigint :party_id, null: false
      t.integer :position, null: false
      t.boolean :dispatch_as_attachment, default: false, null: false
      t.timestamps
    end
    add_index :distribution_list_members, [ :distribution_list_id, :party_type, :party_id ],
              unique: true, name: "index_distribution_list_members_unique"
    add_index :distribution_list_members, [ :distribution_list_id, :position ], unique: true
    add_index :distribution_list_members, [ :party_type, :party_id ]
  end
end
