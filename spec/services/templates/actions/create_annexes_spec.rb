# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::Actions::CreateAnnexes do
  let(:document) { create(:document) }
  let(:ctx) { LightService::Context.make(document: document, annex_files: annex_files) }

  def fixture_upload
    fixture_file_upload("sample.pdf", "application/pdf")
  end

  describe ".execute" do
    context "with a single file" do
      let(:annex_files) { [ fixture_upload ] }

      it "creates one annex" do
        expect { described_class.execute(ctx) }.to change(document.annexes, :count).by(1)
      end

      it "attaches the file to the created annex" do
        described_class.execute(ctx)
        expect(document.annexes.reload.first.file.filename.to_s).to eq("sample.pdf")
      end

      it "succeeds" do
        result = described_class.execute(ctx)
        expect(result).to be_success
      end
    end

    context "with multiple files" do
      let(:annex_files) { [ fixture_upload, fixture_upload ] }

      it "creates one annex per file" do
        expect { described_class.execute(ctx) }.to change(document.annexes, :count).by(2)
      end
    end

    context "with an empty list" do
      let(:annex_files) { [] }

      it "creates no annexes" do
        expect { described_class.execute(ctx) }.not_to change(document.annexes, :count)
      end
    end

    context "when annex_files is nil" do
      let(:annex_files) { nil }

      it "does not raise and creates no annexes" do
        expect { described_class.execute(ctx) }.not_to change(document.annexes, :count)
      end
    end

    context "with blank entries mixed in" do
      let(:annex_files) { [ fixture_upload, "" ] }

      it "ignores the blank entries" do
        expect { described_class.execute(ctx) }.to change(document.annexes, :count).by(1)
      end
    end

    context "when skip_pdf_conversion is not provided" do
      let(:annex_files) { [ fixture_upload ] }

      it "creates annexes with skip_pdf_conversion false" do
        described_class.execute(ctx)
        expect(document.annexes.reload.first.skip_pdf_conversion?).to be(false)
      end
    end

    context "when skip_pdf_conversion is true" do
      let(:ctx) { LightService::Context.make(document: document, annex_files: annex_files, skip_pdf_conversion: true) }
      let(:annex_files) { [ fixture_upload, fixture_upload ] }

      it "creates every annex with skip_pdf_conversion true" do
        described_class.execute(ctx)
        expect(document.annexes.reload.pluck(:skip_pdf_conversion)).to all(be true)
      end
    end
  end
end
