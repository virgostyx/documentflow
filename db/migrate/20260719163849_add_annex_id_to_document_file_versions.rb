class AddAnnexIdToDocumentFileVersions < ActiveRecord::Migration[8.1]
  def change
    add_reference :document_file_versions, :annex, null: true, foreign_key: true

    remove_index :document_file_versions, name: "index_document_file_versions_on_document_id_and_version_number"
    add_index :document_file_versions, [ :document_id, :annex_id, :version_number ],
              unique: true, name: "index_document_file_versions_on_document_annex_version"
  end
end
