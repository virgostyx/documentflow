# frozen_string_literal: true

class AddSubjectTemplateToEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :email_templates, :subject_template, :text
  end
end
