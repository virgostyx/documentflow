# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentFileVersion, type: :model do
  let(:document) { create(:document) }
  let(:user) { create(:user) }

  subject(:version) { build(:document_file_version, document: document, user: user) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:document) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_one_attached(:file) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:version_number) }
    it { is_expected.to validate_numericality_of(:version_number).only_integer.is_greater_than(0) }
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe ".ordered" do
    it "orders versions by version_number ascending" do
      v2 = create(:document_file_version, document: document, user: user, version_number: 2)
      v1 = create(:document_file_version, document: document, user: user, version_number: 1)

      expect(document.document_file_versions.ordered).to eq([ v1, v2 ])
    end
  end

  # ── Class methods ─────────────────────────────────────────────────────────

  describe ".next_version_number" do
    it "returns 1 when the document has no versions yet" do
      expect(DocumentFileVersion.next_version_number(document)).to eq(1)
    end

    it "returns the highest version_number plus one" do
      create(:document_file_version, document: document, user: user, version_number: 1)
      create(:document_file_version, document: document, user: user, version_number: 2)

      expect(DocumentFileVersion.next_version_number(document)).to eq(3)
    end
  end
end
