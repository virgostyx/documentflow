# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailArchive::ExtractOriginalMessage do
  describe ".call" do
    context "with a Redirect-style message (Resent-From present)" do
      it "treats the top-level message as the original and reads the relaying address from Resent-From" do
        mail = build_archive_mail(from: "external@example.com", to: "lead@example.com", resent_from: "relayer@example.com")

        result = described_class.call(mail)

        expect(result.message).to eq(mail)
        expect(result.relaying_address).to eq("relayer@example.com")
      end
    end

    context "with a plain message and no Resent-From" do
      it "returns a nil relaying_address" do
        mail = build_archive_mail(from: "external@example.com", to: "lead@example.com")

        result = described_class.call(mail)

        expect(result.relaying_address).to be_nil
      end
    end

    context "with a Forward-as-attachment-style message (nested message/rfc822)" do
      it "unwraps the attached original message and reads the relaying address from the outer From:" do
        original = build_archive_mail(from: "external@example.com", to: "lead@example.com", subject: "Original subject")
        forwarded = build_forwarded_mail(forwarded_by: "forwarder@example.com", original: original)

        result = described_class.call(forwarded)

        expect(result.message.subject).to eq("Original subject")
        expect(result.message.from).to eq([ "external@example.com" ])
        expect(result.relaying_address).to eq("forwarder@example.com")
      end
    end
  end
end
