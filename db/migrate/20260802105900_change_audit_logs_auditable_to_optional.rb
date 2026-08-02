class ChangeAuditLogsAuditableToOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :audit_logs, :auditable_id, true
    change_column_null :audit_logs, :auditable_type, true
  end
end
