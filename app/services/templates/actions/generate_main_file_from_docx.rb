# frozen_string_literal: true

module Templates
  module Actions
    class GenerateMainFileFromDocx < ApplicationAction
      expects :document, :document_template, :field_values

      executed do |ctx|
        source_file = ctx.document_template.source_file
        filename = source_file.filename.to_s

        Dir.mktmpdir do |dir|
          output_path = File.join(dir, filename)

          source_file.open do |template_file|
            DocxTemplateProcessor.substitute(
              docx_path: template_file.path, values: ctx.field_values || {}, output_path: output_path
            )
          end

          # main_file.attach only reads the io lazily (ActiveStorage uploads on
          # after_commit) - the substituted file must be fully in memory before
          # this tmpdir is cleaned up, not a still-open path-backed handle.
          ctx.document.main_file.attach(
            io: StringIO.new(File.binread(output_path)), filename: filename, content_type: DocumentTemplate::DOCX_CONTENT_TYPE
          )
        end
      end
    end
  end
end
