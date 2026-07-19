# frozen_string_literal: true

require "rails_helper"

RSpec.describe Annex, type: :model do
  let(:document) { create(:document) }

  subject(:annex) { build(:annex, document: document) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:document) }
    it { is_expected.to have_one_attached(:file) }
    it { is_expected.to have_many(:document_file_versions).dependent(:destroy) }
  end

  describe "destroy" do
    it "purges the attached file and destroys its version history" do
      annex.save!
      version = create(:document_file_version, document: document, annex: annex)

      annex.destroy!

      expect(DocumentFileVersion.exists?(version.id)).to be false
    end
  end
end
