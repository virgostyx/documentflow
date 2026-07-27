# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::FilingComponent, type: :component do
  let(:user) { create(:user) }
  let(:document) { create(:document, created_by: user) }
  let(:entity_role) { "admin" }

  before { create(:entity_user, entity: document.entity, user: user, role: entity_role, status: "active") }

  subject { render_inline(described_class.new(document: document, current_user: user)) }

  context "when the document is not classified" do
    it "displays a not filed message" do
      expect(subject).to have_text("Not filed yet.")
    end

    it "displays the change filing action" do
      expect(subject).to have_link("Change filing")
    end
  end

  context "when the document is classified under a root node" do
    let(:node) { create(:classification_node, entity: document.entity, code: "1", name: "Correspondence") }

    before { document.update!(classification_node: node) }

    it "displays the node's code and name without a path separator" do
      expect(subject).to have_text("1 — Correspondence")
    end
  end

  context "when the document is classified under a nested node" do
    let(:root) { create(:classification_node, entity: document.entity, code: "1", name: "Correspondence") }
    let(:child) { create(:classification_node, entity: document.entity, parent: root, code: "1.1", name: "Incoming") }
    let(:grandchild) { create(:classification_node, entity: document.entity, parent: child, code: "1.1.1", name: "Invoices") }

    before { document.update!(classification_node: grandchild) }

    it "displays the full breadcrumb path with the leaf node's name" do
      expect(subject).to have_text("1 › 1.1 › 1.1.1 — Invoices")
    end
  end

  context "when the change filing link is shown" do
    let(:node) { create(:classification_node, entity: document.entity, code: "1", name: "Correspondence") }

    before { document.update!(classification_node: node) }

    it "links to the classify form for the document" do
      expect(subject).to have_css(
        "a[href='#{Rails.application.routes.url_helpers.classify_form_entity_document_path(document.entity, document)}']"
      )
    end
  end

  context "when the current user cannot classify the document" do
    let(:entity) { create(:entity) }
    let(:other_department) { create(:department, entity: entity) }
    let(:document) { create(:document, entity: entity, created_by: create(:user), department: other_department) }
    let(:entity_role) { "member" }

    it "does not display the change filing action" do
      expect(subject).not_to have_link("Change filing")
    end
  end
end
