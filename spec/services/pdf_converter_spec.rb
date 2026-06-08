# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfConverter do
  # A tiny valid PNG (10x10 white square), used so the image conversion example
  # doesn't need a binary fixture file checked into the repo.
  TINY_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKAQAAAAClSfIQAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1" \
    "MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRAAB3YoTpAAAAAd0SU1FB+oGCBECCWfxXGoAAAAOSURBVAjX" \
    "Y/h/gAE3AgAHUhF35sjQ4wAAAABJRU5ErkJggg=="
  )

  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end

  def write_file(name, content)
    path = File.join(@tmp_dir, name)
    File.binwrite(path, content)
    path
  end

  describe ".convert" do
    it "returns the original path when the file is already a PDF" do
      path = write_file("document.pdf", "%PDF-1.4 fake content")

      expect(described_class.convert(path)).to eq(path)
    end

    it "converts a text file to PDF with Prawn" do
      path = write_file("notes.txt", "Hello from the test suite")

      output = described_class.convert(path)

      expect(output).to eq(File.join(@tmp_dir, "notes.pdf"))
      expect(File.binread(output)).to start_with("%PDF")
    end

    it "converts an image file to PDF with Prawn" do
      path = write_file("photo.png", TINY_PNG)

      output = described_class.convert(path)

      expect(output).to eq(File.join(@tmp_dir, "photo.pdf"))
      expect(File.binread(output)).to start_with("%PDF")
    end

    it "converts an office document to PDF via LibreOffice without invoking a shell" do
      path = write_file("contract.docx", "fake docx content")
      output_path = File.join(@tmp_dir, "contract.pdf")

      expect(described_class).to receive(:system).with(
        "soffice", "--headless", "--convert-to", "pdf", "--outdir", @tmp_dir, path
      ) do
        File.write(output_path, "%PDF-1.4 converted")
        true
      end

      expect(described_class.convert(path)).to eq(output_path)
    end

    it "raises a ConversionError when the LibreOffice conversion fails" do
      path = write_file("contract.docx", "fake docx content")

      allow(described_class).to receive(:system).and_return(false)

      expect { described_class.convert(path) }.to raise_error(PdfConverter::ConversionError, /LibreOffice/)
    end

    it "raises a ConversionError for unsupported formats" do
      path = write_file("archive.zip", "fake zip content")

      expect { described_class.convert(path) }.to raise_error(PdfConverter::ConversionError, /Unsupported format/)
    end
  end
end
