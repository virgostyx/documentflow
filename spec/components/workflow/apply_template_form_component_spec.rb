# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflow::ApplyTemplateFormComponent, type: :component do
  let(:entity) { create(:entity) }
  let(:document) { create(:document, entity: entity) }

  subject { render_inline(described_class.new(document: document)) }

  context "when the entity has circuit templates" do
    let!(:circuit_template) { create(:circuit_template, entity: entity, name: "Standard circuit") }

    it "renders a select with the entity's circuit templates" do
      expect(subject).to have_select("circuit_template_id", with_options: [ "Standard circuit" ])
    end

    it "submits to the document's apply_template endpoint" do
      path = Rails.application.routes.url_helpers.apply_template_entity_document_workflow_steps_path(entity, document)
      expect(subject).to have_css("form[action='#{path}']")
    end

    it "displays the apply button" do
      expect(subject).to have_button("Apply")
    end
  end

  context "when the entity has no circuit templates" do
    it "does not render anything" do
      expect(subject.to_html.strip).to be_empty
    end
  end
end
