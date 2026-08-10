# frozen_string_literal: true

# Declares that one or more belongs_to associations must share this record's
# entity_id when present, e.g. `validates_entity_scoped :department`.
module EntityScopedAssociations
  extend ActiveSupport::Concern

  class_methods do
    def validates_entity_scoped(*associations)
      associations.each do |association|
        method_name = :"#{association}_belongs_to_entity"

        define_method(method_name) do
          record = public_send(association)
          return if entity.nil? || record.nil? || record.entity_id == entity_id

          errors.add(association, "must belong to the same entity")
        end
        private method_name

        validate method_name
      end
    end
  end
end
