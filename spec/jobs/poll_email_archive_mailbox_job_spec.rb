# frozen_string_literal: true

require "rails_helper"

RSpec.describe PollEmailArchiveMailboxJob do
  let(:imap) { instance_double(Net::IMAP) }

  around do |example|
    original = %w[EMAIL_ARCHIVE_IMAP_HOST EMAIL_ARCHIVE_IMAP_USERNAME EMAIL_ARCHIVE_IMAP_PASSWORD].index_with { |k| ENV[k] }
    ENV["EMAIL_ARCHIVE_IMAP_HOST"] = "imap.example.com"
    ENV["EMAIL_ARCHIVE_IMAP_USERNAME"] = "archive@example.com"
    ENV["EMAIL_ARCHIVE_IMAP_PASSWORD"] = "secret"
    example.run
    original.each { |k, v| ENV[k] = v }
  end

  before do
    allow(Net::IMAP).to receive(:new).and_return(imap)
    allow(imap).to receive(:login)
    allow(imap).to receive(:select)
    allow(imap).to receive(:store)
    allow(imap).to receive(:logout)
    allow(imap).to receive(:disconnect)
  end

  def fetch_data_for(seq_no, mail)
    instance_double(Net::IMAP::FetchData, seqno: seq_no, attr: { "RFC822" => mail.to_s })
  end

  describe "#perform" do
    context "when IMAP credentials are not configured" do
      before { ENV["EMAIL_ARCHIVE_IMAP_HOST"] = nil }

      it "does nothing and never connects" do
        expect(Net::IMAP).not_to receive(:new)
        described_class.perform_now
      end
    end

    context "with no unseen messages" do
      before { allow(imap).to receive(:search).and_return([]) }

      it "does not create any document" do
        expect { described_class.perform_now }.not_to change(Document, :count)
      end
    end

    context "dispatching a message to the outgoing (BCC) pipeline" do
      let(:entity) { create(:entity) }
      let(:department) { create(:department, entity: entity, archive_ingestion_email: "sales.archive@example.com") }
      let(:user) { create(:user, external_email: "sender@outlook.com") }
      let!(:entity_user) do
        eu = create(:entity_user, entity: entity, user: user, status: "active")
        create(:entity_user_department, entity_user: eu, department: department)
        eu
      end
      let(:mail) { build_archive_mail(from: "sender@outlook.com", to: "client@vendor.com", delivered_to: "sales.archive@example.com") }

      before do
        allow(imap).to receive(:search).and_return([ 1 ])
        allow(imap).to receive(:fetch).with(1, "RFC822").and_return([ fetch_data_for(1, mail) ])
      end

      it "creates an archived outgoing document" do
        expect { described_class.perform_now }.to change(Document, :count).by(1)
        expect(entity.documents.last.archived_from_email?).to be true
      end

      it "marks the message as seen" do
        expect(imap).to receive(:store).with(1, "+FLAGS", [ :Seen ])
        described_class.perform_now
      end
    end

    context "dispatching a message to the incoming (redirect) pipeline" do
      let(:entity) { create(:entity, incoming_archive_email: "incoming.archive@example.com") }
      let(:department) { create(:department, entity: entity) }
      let(:user) { create(:user, external_email: "relayer@outlook.com") }
      let!(:entity_user) do
        eu = create(:entity_user, entity: entity, user: user, status: "active")
        create(:entity_user_department, entity_user: eu, department: department, primary: true)
        eu
      end
      let(:mail) do
        build_archive_mail(
          from: "sender@vendor.com", to: "relayer@outlook.com",
          resent_from: "relayer@outlook.com", delivered_to: "incoming.archive@example.com"
        )
      end

      before do
        allow(imap).to receive(:search).and_return([ 1 ])
        allow(imap).to receive(:fetch).with(1, "RFC822").and_return([ fetch_data_for(1, mail) ])
      end

      it "creates an auto-registered incoming document" do
        expect { described_class.perform_now }.to change(Document, :count).by(1)
        expect(entity.documents.last.direction).to eq("incoming")
      end
    end

    context "when the delivered_to address matches nothing configured" do
      let(:mail) { build_archive_mail(from: "sender@outlook.com", to: "client@vendor.com", delivered_to: "unknown@example.com") }

      before do
        allow(imap).to receive(:search).and_return([ 1 ])
        allow(imap).to receive(:fetch).with(1, "RFC822").and_return([ fetch_data_for(1, mail) ])
      end

      it "does not create a document but still marks the message as seen" do
        expect(imap).to receive(:store).with(1, "+FLAGS", [ :Seen ])
        expect { described_class.perform_now }.not_to change(Document, :count)
      end
    end

    context "when fetching/parsing a message raises an error" do
      before do
        allow(imap).to receive(:search).and_return([ 1 ])
        allow(imap).to receive(:fetch).with(1, "RFC822").and_raise(StandardError, "boom")
      end

      it "does not propagate the error and still marks the message as seen" do
        expect(imap).to receive(:store).with(1, "+FLAGS", [ :Seen ])
        expect { described_class.perform_now }.not_to raise_error
      end
    end
  end
end
