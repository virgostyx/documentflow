# frozen_string_literal: true

require "open-uri"

# Fetches and caches Collabora Online's discovery.xml, which maps a file's
# MIME type to the editor URL template Collabora expects to be embedded at.
# See Wopi::EditUrl for how the template is turned into a concrete iframe src.
module Wopi
  class Discovery
    CACHE_KEY = "wopi/discovery_xml"
    CACHE_TTL = 24.hours

    MIME_TO_EXT = {
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "docx",
      "application/msword" => "doc",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "xlsx",
      "application/vnd.ms-excel" => "xls",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" => "pptx",
      "application/vnd.ms-powerpoint" => "ppt",
      "application/vnd.oasis.opendocument.text" => "odt",
      "application/vnd.oasis.opendocument.spreadsheet" => "ods",
      "application/vnd.oasis.opendocument.presentation" => "odp"
    }.freeze

    def self.edit_url_template(content_type:)
      new.edit_url_template(content_type: content_type)
    end

    def edit_url_template(content_type:)
      ext = MIME_TO_EXT[content_type]
      return nil if ext.nil?

      action = actions.find { |node| node["ext"] == ext }
      action && action["urlsrc"]
    end

    private

    def actions
      document.xpath("//app/action[@name='edit']")
    end

    def document
      @document ||= Nokogiri::XML(discovery_xml)
    end

    def discovery_xml
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        URI.parse("#{collabora_base_url}/hosting/discovery").open.read
      end
    end

    def collabora_base_url
      ENV.fetch("COLLABORA_BASE_URL")
    end
  end
end
