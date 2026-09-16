# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailArchive::RenderBodyToPdf do
  describe ".call" do
    it "renders a multipart/alternative message's html_part to a PDF" do
      mail = build_archive_mail(from: "external@example.com", to: "lead@example.com", body: "<p>Hello there</p>")

      result = described_class.call(mail)

      expect(result[:content_type]).to eq("application/pdf")
      expect(result[:io].read).to start_with("%PDF")
    end

    it "renders a single-part text/html message (no nested html_part) without raising on charset transcoding" do
      mail = build_single_part_html_mail(from: "external@example.com", to: "lead@example.com", html_body: "<p>Réponse avec accents ’ et —</p>")

      expect { described_class.call(mail) }.not_to raise_error

      result = described_class.call(mail)
      expect(result[:io].read).to start_with("%PDF")
    end

    it "renders a single-part text/plain message without raising on charset transcoding" do
      mail = build_single_part_text_mail(from: "external@example.com", to: "lead@example.com", text_body: "Réponse avec accents ’ et —")

      expect { described_class.call(mail) }.not_to raise_error

      result = described_class.call(mail)
      expect(result[:io].read).to start_with("%PDF")
    end
  end
end
