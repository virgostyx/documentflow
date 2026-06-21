# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::ClassificationOrganizer do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:document) { create(:document, entity: entity, department: department) }
  let(:node) { create(:classification_node, entity: entity, code: "1", name: "Administration") }

  let(:user) do
    create(:user).tap do |u|
      create(:entity_user, user: u, entity: entity, role: "member", status: "active")
    end
  end

  describe ".call" do
    context "with a classification node" do
      it "classifies the document under the node" do
        result = described_class.call(document: document, classification_node: node, current_user: user)

        expect(result).to be_success
        expect(document.reload.classification_node).to eq(node)
      end
    end

    it "classifies the document regardless of which department it belongs to" do
      other_department = create(:department, entity: entity)
      document_in_other_department = create(:document, entity: entity, department: other_department)

      result = described_class.call(document: document_in_other_department, classification_node: node, current_user: user)

      expect(result).to be_success
      expect(document_in_other_department.reload.classification_node).to eq(node)
    end

    context "with classification_node: nil" do
      it "removes the document's classification" do
        document.update!(classification_node: node)

        result = described_class.call(document: document, classification_node: nil, current_user: user)

        expect(result).to be_success
        expect(document.reload.classification_node).to be_nil
      end
    end

    context "when the node belongs to a different entity than the document" do
      let(:other_entity) { create(:entity) }
      let(:foreign_node) { create(:classification_node, entity: other_entity, code: "1", name: "Other entity root") }

      it "fails without changing the document" do
        result = described_class.call(document: document, classification_node: foreign_node, current_user: user)

        expect(result).not_to be_success
        expect(document.reload.classification_node).to be_nil
      end
    end
  end
end
