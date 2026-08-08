# frozen_string_literal: true

require "zip"

module Templates
  # Detects and substitutes {{tag}} placeholders in a .docx's body
  # (word/document.xml). Word frequently splits a visually-continuous string
  # like "{{supplier}}" across multiple <w:r> runs (autocorrect, a formatting
  # change mid-type), so both operations work on each paragraph's
  # concatenated <w:t> text rather than matching node-by-node.
  class DocxTemplateProcessor
    TAG_PATTERN = Templates::TagScanner::TAG_PATTERN
    WORD_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    NS = { "w" => WORD_NS }.freeze
    DOCUMENT_ENTRY = "word/document.xml"

    class << self
      def tags_in(docx_path)
        document_for(docx_path).xpath("//w:p", NS).flat_map { |paragraph| paragraph_text(paragraph).scan(TAG_PATTERN) }
                                .flatten.uniq
      end

      def substitute(docx_path:, values:, output_path:)
        doc = document_for(docx_path)
        doc.xpath("//w:p", NS).each { |paragraph| substitute_in_paragraph(paragraph, values) }
        new_document_xml = doc.to_xml

        # Rebuilds the whole archive from scratch instead of patching the
        # document.xml entry in place: an in-place Zip::File rewrite doesn't
        # relocate the entries that physically follow it, so once the
        # substituted document.xml's size differs from the original it
        # corrupts every entry after it (rubyzip's own reader is lenient
        # enough not to notice, but LibreOffice/Word reject the result).
        output_stream = Zip::OutputStream.new(output_path)
        begin
          Zip::File.open(docx_path) do |zip|
            zip.each do |entry|
              next unless entry.file?

              output_stream.put_next_entry(entry.name)
              output_stream.write(entry.name == DOCUMENT_ENTRY ? new_document_xml : entry.get_input_stream.read)
            end
          end
        ensure
          output_stream.close
        end
      end

      private

      def document_for(docx_path)
        Nokogiri::XML(Zip::File.open(docx_path) { |zip| zip.read(DOCUMENT_ENTRY) })
      end

      def paragraph_text(paragraph)
        paragraph.xpath(".//w:t", NS).map(&:text).join
      end

      def substitute_in_paragraph(paragraph, values)
        nodes = paragraph.xpath(".//w:t", NS).to_a
        return if nodes.empty?

        offset = 0
        spans = nodes.map do |node|
          text = node.text
          span = [ node, offset, offset + text.length ]
          offset += text.length
          span
        end
        full_text = nodes.map(&:text).join

        matches = full_text.to_enum(:scan, TAG_PATTERN).map { Regexp.last_match }
        return if matches.empty?

        node_groups(matches, spans).each do |first_index, last_index|
          slice_start = spans[first_index][1]
          slice_end = spans[last_index][2]
          new_text = full_text[slice_start...slice_end].gsub(TAG_PATTERN) { values[Regexp.last_match(1)].to_s }

          spans[first_index][0].content = new_text
          ((first_index + 1)..last_index).each { |i| spans[i][0].content = "" }
        end
      end

      # Merges matches that touch the same <w:t> node (e.g. two tags typed in
      # one run) into a single group, so the group is substituted as one
      # block instead of each match separately overwriting the node.
      def node_groups(matches, spans)
        groups = []

        matches.each do |match|
          touched = spans.each_index.select { |i| spans[i][1] < match.end(0) && spans[i][2] > match.begin(0) }
          first, last = touched.first, touched.last

          if groups.any? && first <= groups.last[1]
            groups.last[1] = [ groups.last[1], last ].max
          else
            groups << [ first, last ]
          end
        end

        groups
      end
    end
  end
end
