# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailArchive::CreateOrganizer do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity, archive_ingestion_email: "sales.archive@example.com") }
  let(:user) { create(:user, external_email: "sender@outlook.com") }

  let!(:entity_user) do
    eu = create(:entity_user, entity: entity, user: user, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  describe ".call" do
    context "with a valid BCC'd message" do
      let(:mail) do
        build_archive_mail(
          from: "sender@outlook.com",
          to: [ "client@vendor.com", "second@vendor.com" ],
          cc: "watcher@vendor.com",
          subject: "Contract renewal",
          delivered_to: "sales.archive@example.com"
        )
      end

      it "creates an already-finalized, archived outgoing document" do
        expect {
          described_class.call(mail: mail, delivered_to: "sales.archive@example.com")
        }.to change(Document, :count).by(1)

        document = entity.documents.last
        expect(document.direction).to eq("outgoing")
        expect(document.status).to eq("finalized")
        expect(document).to be_frozen
        expect(document.archived_from_email?).to be true
        expect(document.department).to eq(department)
        expect(document.sender).to eq(user)
        expect(document.addressee).to be_a(Contact)
        expect(document.addressee.email).to eq("client@vendor.com")
        expect(document.reference_number).to match(/\A[A-Z0-9]{1,8}\(\d{4}\)\d{5}\z/)
        expect(document.temporary_number).to be_nil
      end

      it "attaches the rendered body as main_file" do
        described_class.call(mail: mail, delivered_to: "sales.archive@example.com")
        expect(entity.documents.last.main_file).to be_attached
      end

      it "creates cc_recipients for the other To/Cc addresses" do
        described_class.call(mail: mail, delivered_to: "sales.archive@example.com")

        document = entity.documents.last
        cc_emails = document.cc_recipients.map { |cc| cc.party.email }
        expect(cc_emails).to contain_exactly("second@vendor.com", "watcher@vendor.com")
      end

      it "returns a successful result" do
        result = described_class.call(mail: mail, delivered_to: "sales.archive@example.com")
        expect(result).to be_success
      end

      it "logs an audit event" do
        expect {
          described_class.call(mail: mail, delivered_to: "sales.archive@example.com")
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "when no department matches the delivered_to address" do
      let(:mail) { build_archive_mail(from: "sender@outlook.com", to: "client@vendor.com") }

      it "does not create a document and returns a failure" do
        expect {
          @result = described_class.call(mail: mail, delivered_to: "unknown@example.com")
        }.not_to change(Document, :count)

        expect(@result).not_to be_success
        expect(@result.message).to include("No department configured")
      end
    end

    context "when the From: address does not match any authorized user" do
      let(:mail) do
        build_archive_mail(from: "stranger@outlook.com", to: "client@vendor.com", delivered_to: "sales.archive@example.com")
      end

      it "does not create a document and returns a failure" do
        expect {
          @result = described_class.call(mail: mail, delivered_to: "sales.archive@example.com")
        }.not_to change(Document, :count)

        expect(@result).not_to be_success
        expect(@result.message).to include("Could not resolve an authorized sender")
      end
    end

    context "when the sending user is not a member of the target department" do
      let(:outsider) { create(:user, external_email: "outsider@outlook.com") }
      let!(:outsider_entity_user) { create(:entity_user, entity: entity, user: outsider, role: "member", status: "active") }
      let(:mail) do
        build_archive_mail(from: "outsider@outlook.com", to: "client@vendor.com", delivered_to: "sales.archive@example.com")
      end

      it "does not create a document" do
        expect {
          described_class.call(mail: mail, delivered_to: "sales.archive@example.com")
        }.not_to change(Document, :count)
      end
    end

    context "when the message has no To recipient" do
      let(:mail) do
        Mail.new do
          from "sender@outlook.com"
          subject "No recipient"
        end.tap { |m| m["Delivered-To"] = "sales.archive@example.com" }
      end

      it "does not create a document and returns a failure" do
        expect {
          @result = described_class.call(mail: mail, delivered_to: "sales.archive@example.com")
        }.not_to change(Document, :count)

        expect(@result).not_to be_success
        expect(@result.message).to include("no To recipient")
      end
    end
  end
end
