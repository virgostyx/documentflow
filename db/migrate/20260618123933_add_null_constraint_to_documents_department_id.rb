# frozen_string_literal: true

class AddNullConstraintToDocumentsDepartmentId < ActiveRecord::Migration[8.1]
  def up
    change_column_null :documents, :department_id, false
  end

  def down
    change_column_null :documents, :department_id, true
  end
end
