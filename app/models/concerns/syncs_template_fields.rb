# frozen_string_literal: true

# Keeps a has_many "fields" association (tag_name/label/field_type/required)
# in sync with the tags actually referenced by the template (see #tags),
# creating rows for new tags and removing rows for tags no longer used.
# The including class must define #tags and a RESERVED_TAGS constant.
module SyncsTemplateFields
  extend ActiveSupport::Concern

  class_methods do
    def syncs_template_fields(association)
      # after_commit, not after_save: for templates backed by an attached file
      # (has_one_attached), the blob's bytes only become readable on
      # after_commit - reading #tags any earlier could race the upload.
      after_commit :sync_template_fields, on: %i[create update]

      define_method(:sync_template_fields) do
        fields = public_send(association)
        tag_names = tags - self.class::RESERVED_TAGS
        existing_tags = fields.pluck(:tag_name)

        new_tags = tag_names - existing_tags
        new_tags.each_with_index do |tag, index|
          fields.create!(
            tag_name: tag, label: tag.humanize, field_type: "text", required: true,
            position: next_field_position + index
          )
        end

        stale_tags = existing_tags - tag_names
        fields.where(tag_name: stale_tags).destroy_all if stale_tags.any?
      end
      private :sync_template_fields

      define_method(:next_field_position) do
        (public_send(association).maximum(:position) || 0) + 1
      end
      private :next_field_position
    end
  end
end
