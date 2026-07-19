# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::FileVersionListComponent, type: :component do
  let(:document) { create(:document) }
  let(:user) { create(:user, email: "reviewer@example.com") }

  subject { render_inline(described_class.new(document: document)) }

  context "when the document has no file versions" do
    it "renders nothing" do
      expect(subject.to_html.strip).to be_empty
    end
  end

  context "when the document has file versions" do
    let!(:v1) { create(:document_file_version, document: document, user: user, version_number: 1, comment: "Initial draft") }
    let!(:v2) { create(:document_file_version, document: document, user: user, version_number: 2, comment: nil) }

    it "lists versions with the most recent first" do
      rows = subject.css("li").map(&:text)
      expect(rows.first).to include("Version 2")
      expect(rows.last).to include("Version 1")
    end

    it "shows the uploader's email and comment" do
      expect(subject).to have_text("reviewer@example.com")
      expect(subject).to have_text("Initial draft")
    end

    it "links to download each version" do
      expect(subject).to have_link("Download", href: Rails.application.routes.url_helpers.rails_blob_path(v2.file, disposition: "attachment", only_path: true))
    end

    it "labels main-file versions as such" do
      rows = subject.css("li").map(&:text)
      expect(rows).to all(include("Main file"))
    end
  end

  context "when a version belongs to an annex" do
    let(:annex) { create(:annex, document: document) }
    let!(:version) { create(:document_file_version, document: document, user: user, annex: annex, version_number: 1) }

    it "labels the row with the annex's filename" do
      rows = subject.css("li").map(&:text)
      expect(rows.first).to include(annex.file.filename.to_s)
    end
  end
end
