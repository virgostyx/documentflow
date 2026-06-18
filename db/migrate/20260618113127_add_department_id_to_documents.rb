# frozen_string_literal: true

class AddDepartmentIdToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_reference :documents, :department, null: true, foreign_key: true
  end
end
