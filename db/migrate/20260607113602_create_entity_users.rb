class CreateEntityUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :entity_users do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users }
      t.string :role, null: false, default: "member"
      t.string :status, null: false, default: "pending"
      t.string :invited_email, null: false
      t.string :invitation_token
      t.datetime :invited_at
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :entity_users, [ :entity_id, :user_id ], unique: true
    add_index :entity_users, :role
    add_index :entity_users, :status
    add_index :entity_users, :invitation_token, unique: true
  end
end
