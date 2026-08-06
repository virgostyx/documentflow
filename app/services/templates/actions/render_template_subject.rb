# frozen_string_literal: true

module Templates
  module Actions
    class RenderTemplateSubject < ApplicationAction
      expects :document_template, :field_values, :document_params
      promises :document_params

      executed do |ctx|
        field_values = ctx.field_values || {}
        template = ctx.document_template

        missing_fields = template.document_template_fields.select do |field|
          field.required? && field_values[field.tag_name].blank?
        end

        if missing_fields.any?
          next fail_with!(ctx, "Missing required field(s): #{missing_fields.map(&:label).join(', ')}", :validation_error)
        end

        rendered_subject = template.subject_template.gsub(DocumentTemplate::TAG_PATTERN) do
          field_values[Regexp.last_match(1)].to_s
        end

        ctx.document_params = ctx.document_params.merge(subject: rendered_subject)
      end
    end
  end
end
