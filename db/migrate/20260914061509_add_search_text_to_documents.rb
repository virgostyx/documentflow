class AddSearchTextToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :search_text, :text
    add_index :documents, :search_text, using: :gin, opclass: :gin_trgm_ops, name: "index_documents_on_search_text_trgm"
    add_index :documents, :document_date

    reversible do |dir|
      dir.up do
        Document.reset_column_information
        Document.find_each { |d| d.update_column(:search_text, Document.compute_search_text(d)) }
      end
    end
  end
end
