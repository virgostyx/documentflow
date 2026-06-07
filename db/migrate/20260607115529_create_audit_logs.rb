class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :auditable, polymorphic: true, null: false
      t.string :action, null: false
      t.jsonb :change_data, default: {}
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :audit_logs, [ :auditable_type, :auditable_id ]
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
  end
end
