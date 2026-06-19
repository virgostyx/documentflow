class AddResponseDeadlineToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :response_deadline, :date
  end
end
