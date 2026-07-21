# frozen_string_literal: true

class AddNullConstraintToEntitiesPrefix < ActiveRecord::Migration[8.1]
  def up
    change_column_null :entities, :prefix, false
  end

  def down
    change_column_null :entities, :prefix, true
  end
end
