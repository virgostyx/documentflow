# frozen_string_literal: true

require "zip"

# Builds minimal but complete .docx (OOXML) fixture files for specs, without
# depending on Word/LibreOffice to author them. Includes the package parts
# required for the result to be a genuinely openable .docx (not just
# something Templates::DocxTemplateProcessor's own lenient zip reading
# tolerates) - [Content_Types].xml and _rels/.rels are mandatory OPC parts;
# omitting them lets LibreOffice reject even an unmodified fixture.
module DocxHelpers
  CONTENT_TYPES_XML = <<~XML
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
  XML

  ROOT_RELS_XML = <<~XML
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
  XML

  def build_docx(path, paragraphs_xml, extra_entries: {})
    document_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>#{paragraphs_xml}</w:body>
      </w:document>
    XML

    Zip::File.open(path, create: true) do |zip|
      zip.get_output_stream("[Content_Types].xml") { |f| f.write(CONTENT_TYPES_XML) }
      zip.get_output_stream("_rels/.rels") { |f| f.write(ROOT_RELS_XML) }
      zip.get_output_stream("word/document.xml") { |f| f.write(document_xml) }
      extra_entries.each { |name, content| zip.get_output_stream(name) { |f| f.write(content) } }
    end
  end

  # One paragraph made of one <w:r> run per given text fragment - pass several
  # fragments to simulate Word splitting a tag like "{{supplier}}" across runs.
  def docx_paragraph(*run_texts)
    runs = run_texts.map { |text| %(<w:r><w:t xml:space="preserve">#{text}</w:t></w:r>) }.join
    "<w:p>#{runs}</w:p>"
  end

  def read_docx_document_xml(path)
    Zip::File.open(path) { |zip| zip.read("word/document.xml") }
  end

  # Builds a minimal docx with the given paragraphs and attaches it to
  # record.public_send(attribute), for specs that need a template's
  # source_file attached rather than a raw fixture path.
  def attach_docx(record, attribute, paragraphs_xml, filename: "template.docx")
    Dir.mktmpdir do |dir|
      path = File.join(dir, filename)
      build_docx(path, paragraphs_xml)
      record.public_send(attribute).attach(
        io: File.open(path), filename: filename, content_type: DocumentTemplate::DOCX_CONTENT_TYPE
      )
    end
  end
end

RSpec.configure do |config|
  config.include DocxHelpers
end
