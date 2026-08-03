# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailArchive::IncomingMailIngestor do
  let(:entity) { create(:entity, incoming_archive_email: "incoming@archive.example.com") }
  let(:department) { create(:department, entity: entity) }
  let(:user) { create(:user, external_email: "relayer@outlook.com") }

  let!(:entity_user) do
    eu = create(:entity_user, entity: entity, user: user, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department, primary: true)
    eu
  end

  describe ".call" do
    context "with a Redirect-style message from a known user to a known entity" do
      let(:mail) do
        build_archive_mail(
          from: "sender@vendor.com",
          to: "relayer@outlook.com",
          subject: "Invoice #123",
          resent_from: "relayer@outlook.com",
          delivered_to: "incoming@archive.example.com"
        )
      end

      it "auto-registers an incoming document via IncomingMails::RegisterOrganizer" do
        expect {
          described_class.call(mail, delivered_to: "incoming@archive.example.com")
        }.to change(Document, :count).by(1)

        document = entity.documents.last
        expect(document.direction).to eq("incoming")
        expect(document.department).to eq(department)
        expect(document.lead_user).to eq(user)
        expect(document.subject).to eq("Invoice #123")
        expect(document.sender).to be_a(Contact)
        expect(document.sender.email).to eq("sender@vendor.com")
      end

      it "returns a successful result" do
        result = described_class.call(mail, delivered_to: "incoming@archive.example.com")
        expect(result).to be_success
      end

      it "files the document under the pending triage queue for the relaying user" do
        described_class.call(mail, delivered_to: "incoming@archive.example.com")

        expect(Document.pending_triage_for(user)).to include(entity.documents.last)
      end

      it "reuses an existing Contact for the same sender address" do
        existing = create(:contact, entity: entity, email: "sender@vendor.com")

        described_class.call(mail, delivered_to: "incoming@archive.example.com")

        expect(entity.documents.last.sender).to eq(existing)
        expect(Contact.where(entity: entity, email: "sender@vendor.com").count).to eq(1)
      end
    end

    context "when no entity matches the delivered_to address" do
      let(:mail) { build_archive_mail(from: "sender@vendor.com", to: "relayer@outlook.com", resent_from: "relayer@outlook.com") }

      it "does not create a document and returns a failure" do
        expect {
          @result = described_class.call(mail, delivered_to: "unknown@archive.example.com")
        }.not_to change(Document, :count)

        expect(@result).not_to be_success
        expect(@result.reason).to include("no entity configured")
      end
    end

    context "when the relaying address does not match any user" do
      let(:mail) do
        build_archive_mail(
          from: "sender@vendor.com", to: "relayer@outlook.com",
          resent_from: "stranger@outlook.com", delivered_to: "incoming@archive.example.com"
        )
      end

      it "does not create a document and returns a failure" do
        expect {
          @result = described_class.call(mail, delivered_to: "incoming@archive.example.com")
        }.not_to change(Document, :count)

        expect(@result).not_to be_success
        expect(@result.reason).to include("could not resolve relaying user")
      end
    end

    context "when there is no Resent-From and no forwarded attachment" do
      let(:mail) { build_archive_mail(from: "sender@vendor.com", to: "relayer@outlook.com", delivered_to: "incoming@archive.example.com") }

      it "does not create a document" do
        expect {
          described_class.call(mail, delivered_to: "incoming@archive.example.com")
        }.not_to change(Document, :count)
      end
    end
  end
end
