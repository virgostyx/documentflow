# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::FileOrganizer do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:document) { create(:document, entity: entity, department: department) }
  let(:folder) { create(:folder, entity: entity, department: department) }

  let(:user) do
    create(:user).tap do |u|
      eu = create(:entity_user, user: u, entity: entity, role: "member", status: "active")
      create(:entity_user_department, entity_user: eu, department: department)
    end
  end

  describe ".call" do
    context "with a folder accessible to the user" do
      it "files the document into the folder" do
        result = described_class.call(document: document, folder: folder, current_user: user)

        expect(result).to be_success
        expect(document.reload.folder).to eq(folder)
      end
    end

    context "with folder: nil" do
      it "removes the document from its folder" do
        document.update!(folder: folder)

        result = described_class.call(document: document, folder: nil, current_user: user)

        expect(result).to be_success
        expect(document.reload.folder).to be_nil
      end
    end

    context "when the folder belongs to a different department than the document" do
      let(:other_department) { create(:department, entity: entity) }
      let(:foreign_folder) { create(:folder, entity: entity, department: other_department) }

      it "fails without changing the document" do
        result = described_class.call(document: document, folder: foreign_folder, current_user: user)

        expect(result).not_to be_success
        expect(document.reload.folder).to be_nil
      end
    end

    context "when the user has no access to the folder's department" do
      let(:other_department) { create(:department, entity: entity) }
      let(:other_folder) { create(:folder, entity: entity, department: other_department) }
      let(:document) { create(:document, entity: entity, department: other_department) }

      it "fails without changing the document" do
        result = described_class.call(document: document, folder: other_folder, current_user: user)

        expect(result).not_to be_success
        expect(document.reload.folder).to be_nil
      end
    end
  end
end
