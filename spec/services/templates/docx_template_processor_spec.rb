# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::DocxTemplateProcessor do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end

  def path_for(name)
    File.join(@tmp_dir, name)
  end

  describe ".tags_in" do
    it "finds a tag entirely within a single run" do
      path = path_for("single_run.docx")
      build_docx(path, docx_paragraph("Dear {{supplier}}, hello."))

      expect(described_class.tags_in(path)).to eq([ "supplier" ])
    end

    it "finds a tag split across multiple runs" do
      path = path_for("split_run.docx")
      build_docx(path, docx_paragraph("Dear {{sup", "plier}}, hello."))

      expect(described_class.tags_in(path)).to eq([ "supplier" ])
    end

    it "finds multiple distinct tags across paragraphs, in order of first appearance, deduplicated" do
      path = path_for("multi.docx")
      build_docx(
        path,
        docx_paragraph("Supplier: {{supplier}}") + docx_paragraph("Amount: {{amount}}, again {{supplier}}")
      )

      expect(described_class.tags_in(path)).to eq([ "supplier", "amount" ])
    end

    it "returns an empty array when there are no tags" do
      path = path_for("none.docx")
      build_docx(path, docx_paragraph("Nothing to see here."))

      expect(described_class.tags_in(path)).to eq([])
    end
  end

  describe ".substitute" do
    it "replaces a tag entirely within a single run" do
      path = path_for("in.docx")
      output = path_for("out.docx")
      build_docx(path, docx_paragraph("Dear {{supplier}}, hello."))

      described_class.substitute(docx_path: path, values: { "supplier" => "Acme Corp" }, output_path: output)

      expect(read_docx_document_xml(output)).to include("Dear Acme Corp, hello.")
    end

    it "replaces a tag split across multiple runs" do
      path = path_for("in.docx")
      output = path_for("out.docx")
      build_docx(path, docx_paragraph("Dear {{sup", "plier}}, hello."))

      described_class.substitute(docx_path: path, values: { "supplier" => "Acme Corp" }, output_path: output)

      xml = read_docx_document_xml(output)
      expect(xml).to include("Dear Acme Corp, hello.")
      expect(xml).not_to include("{{")
    end

    it "replaces multiple tags in the same paragraph" do
      path = path_for("in.docx")
      output = path_for("out.docx")
      build_docx(path, docx_paragraph("Supplier {{supplier}} owes {{amount}}."))

      described_class.substitute(
        docx_path: path, values: { "supplier" => "Acme Corp", "amount" => "1200 EUR" }, output_path: output
      )

      expect(read_docx_document_xml(output)).to include("Supplier Acme Corp owes 1200 EUR.")
    end

    it "leaves an untagged run in the same paragraph untouched" do
      path = path_for("in.docx")
      output = path_for("out.docx")
      # Two separate <w:r> runs in one paragraph: the tag is entirely within the
      # first run, so the second run's node must not be touched at all.
      build_docx(path, docx_paragraph("Dear {{supplier}}, ", "please read carefully."))

      described_class.substitute(docx_path: path, values: { "supplier" => "Acme Corp" }, output_path: output)

      xml = read_docx_document_xml(output)
      expect(xml).to include("Dear Acme Corp, ")
      expect(xml).to include("please read carefully.")
    end

    it "substitutes an empty string for a tag with no provided value" do
      path = path_for("in.docx")
      output = path_for("out.docx")
      build_docx(path, docx_paragraph("Dear {{supplier}}, hello."))

      described_class.substitute(docx_path: path, values: {}, output_path: output)

      expect(read_docx_document_xml(output)).to include("Dear , hello.")
    end

    it "leaves unrelated paragraph text untouched" do
      path = path_for("in.docx")
      output = path_for("out.docx")
      build_docx(path, docx_paragraph("Untouched paragraph with no tags at all."))

      described_class.substitute(docx_path: path, values: { "supplier" => "Acme Corp" }, output_path: output)

      expect(read_docx_document_xml(output)).to include("Untouched paragraph with no tags at all.")
    end

    it "produces a document LibreOffice can still open when the substitution changes document.xml's size" do
      path = path_for("in.docx")
      output = path_for("out.docx")
      # A real .docx has several entries after word/document.xml (styles.xml,
      # fontTable.xml, ...). Growing document.xml during substitution must not
      # corrupt the physical zip layout of those other entries - rubyzip's own
      # reader is too lenient to catch this (it wrote the corruption, so it
      # reads it back consistently), so LibreOffice is the ground truth here,
      # same as PdfConverter's own specs rely on real soffice conversion.
      build_docx(
        path, docx_paragraph("Dear {{supplier}}, {{amount}}, {{tpin}}, hello."),
        extra_entries: { "word/styles.xml" => "PADDING-#{'x' * 500}" }
      )

      described_class.substitute(
        docx_path: path, values: { "supplier" => "A much longer replacement value than the original short tag" },
        output_path: output
      )

      pdf_path = PdfConverter.convert(output)
      expect(File.binread(pdf_path)).to start_with("%PDF")
    end

    it "does not mutate the original file" do
      path = path_for("in.docx")
      output = path_for("out.docx")
      build_docx(path, docx_paragraph("Dear {{supplier}}, hello."))
      original_xml = read_docx_document_xml(path)

      described_class.substitute(docx_path: path, values: { "supplier" => "Acme Corp" }, output_path: output)

      expect(read_docx_document_xml(path)).to eq(original_xml)
    end
  end
end
