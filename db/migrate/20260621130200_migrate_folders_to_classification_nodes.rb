class MigrateFoldersToClassificationNodes < ActiveRecord::Migration[8.1]
  class MigrationFolder < ActiveRecord::Base
    self.table_name = "folders"
  end

  class MigrationClassificationNode < ActiveRecord::Base
    self.table_name = "classification_nodes"
  end

  class MigrationDocument < ActiveRecord::Base
    self.table_name = "documents"
  end

  def up
    MigrationFolder.distinct.pluck(:entity_id).each do |entity_id|
      roots = MigrationFolder.where(entity_id: entity_id, parent_id: nil).order(:id)

      roots.each_with_index do |root, root_index|
        root_code = (root_index + 1).to_s
        new_root = MigrationClassificationNode.create!(
          entity_id: entity_id, code: root_code, name: root.name, depth: 1,
          created_at: root.created_at, updated_at: root.updated_at
        )
        remap_folder(root.id, new_root.id)

        children = MigrationFolder.where(parent_id: root.id).order(:id)
        children.each_with_index do |child, child_index|
          child_code = "#{root_code}.#{child_index + 1}"
          new_child = MigrationClassificationNode.create!(
            entity_id: entity_id, parent_id: new_root.id, code: child_code, name: child.name, depth: 2,
            created_at: child.created_at, updated_at: child.updated_at
          )
          remap_folder(child.id, new_child.id)
        end
      end
    end
  end

  def down
    MigrationDocument.where.not(classification_node_id: nil).update_all(classification_node_id: nil)
    MigrationClassificationNode.delete_all
  end

  private

  def remap_folder(old_folder_id, new_node_id)
    MigrationDocument.where(folder_id: old_folder_id).update_all(classification_node_id: new_node_id)
  end
end
