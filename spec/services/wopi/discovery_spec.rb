# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wopi::Discovery do
  let(:discovery_xml) do
    <<~XML
      <wopi-discovery>
        <net-zone name="external-http">
          <app name="Writer">
            <action name="edit" ext="docx" urlsrc="https://office.example.com/browser/1234/cool.html?" />
            <action name="view" ext="docx" urlsrc="https://office.example.com/browser/1234/cool.html?" />
          </app>
        </net-zone>
      </wopi-discovery>
    XML
  end

  before do
    allow(Rails.cache).to receive(:fetch).with(described_class::CACHE_KEY, expires_in: described_class::CACHE_TTL).and_return(discovery_xml)
  end

  describe "#edit_url_template" do
    it "returns the edit urlsrc for a known content type" do
      template = described_class.new.edit_url_template(
        content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      )

      expect(template).to eq("https://office.example.com/browser/1234/cool.html?")
    end

    it "returns nil for a content type Collabora has no editor for" do
      template = described_class.new.edit_url_template(content_type: "image/png")

      expect(template).to be_nil
    end
  end
end
