# frozen_string_literal: true

class AddNullConstraintToDepartmentsPrefix < ActiveRecord::Migration[8.1]
  def up
    change_column_null :departments, :prefix, false
  end

  def down
    change_column_null :departments, :prefix, true
  end
end
