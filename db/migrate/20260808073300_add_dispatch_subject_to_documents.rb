# frozen_string_literal: true

class AddDispatchSubjectToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :dispatch_subject, :string
  end
end
