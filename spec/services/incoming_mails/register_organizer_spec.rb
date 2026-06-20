# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomingMails::RegisterOrganizer do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:user) { create(:user) }
  let(:lead) { create(:user) }
  let(:sender) { create(:contact, entity: entity) }

  let!(:entity_user) do
    eu = create(:entity_user, entity: entity, user: user, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let!(:lead_entity_user) do
    eu = create(:entity_user, entity: entity, user: lead, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let(:document_params) do
    {
      subject: "Tax notice",
      document_date: Date.current,
      department_id: department.id,
      sender_token: "Contact-#{sender.id}",
      lead_user_id: lead.id
    }
  end

  describe ".call" do
    context "with valid params" do
      it "creates an incoming document with the lead as addressee" do
        expect {
          described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.to change(Document, :count).by(1)

        document = entity.documents.last
        expect(document.direction).to eq("incoming")
        expect(document.status).to eq("draft")
        expect(document.lead_user).to eq(lead)
        expect(document.addressee).to eq(lead)
        expect(document.created_by).to eq(user)
      end

      it "returns the created document in the context" do
        result = described_class.call(entity: entity, current_user: user, document_params: document_params)

        expect(result).to be_success
        expect(result.document).to be_a(Document)
        expect(result.document.subject).to eq("Tax notice")
      end

      it "logs an audit event" do
        expect {
          described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.to change(AuditLog, :count).by(1)
      end

      it "notifies the lead" do
        expect(NotificationJob).to receive(:perform_later).with(lead.id, "mail_lead_assigned", anything)

        described_class.call(entity: entity, current_user: user, document_params: document_params)
      end
    end

    context "with invalid params" do
      let(:document_params) do
        { subject: "", document_date: nil, department_id: department.id,
          sender_token: "Contact-#{sender.id}", lead_user_id: lead.id }
      end

      it "does not create a document" do
        expect {
          described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.not_to change(Document, :count)
      end

      it "returns a failure with an error message" do
        result = described_class.call(entity: entity, current_user: user, document_params: document_params)

        expect(result).not_to be_success
        expect(result.message).to be_present
      end
    end

    context "when the registering user is not a member of the selected department" do
      let(:other_department) { create(:department, entity: entity) }
      let(:document_params) do
        {
          subject: "Tax notice",
          document_date: Date.current,
          department_id: other_department.id,
          sender_token: "Contact-#{sender.id}",
          lead_user_id: lead.id
        }
      end

      it "does not create a document and returns an explicit message" do
        result = nil
        expect {
          result = described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.not_to change(Document, :count)

        expect(result).not_to be_success
        expect(result.message).to include("not a member of the selected department")
      end
    end

    context "when the chosen lead is not a member of the selected department" do
      let(:outsider) { create(:user) }
      let!(:outsider_entity_user) { create(:entity_user, entity: entity, user: outsider, status: "active") }
      let(:document_params) do
        {
          subject: "Tax notice",
          document_date: Date.current,
          department_id: department.id,
          sender_token: "Contact-#{sender.id}",
          lead_user_id: outsider.id
        }
      end

      it "does not create a document and returns an explicit message" do
        result = nil
        expect {
          result = described_class.call(entity: entity, current_user: user, document_params: document_params)
        }.not_to change(Document, :count)

        expect(result).not_to be_success
        expect(result.message).to include("Lead")
      end
    end

    context "when the current user is an owner who is not a member of any department" do
      let(:owner) { create(:user) }
      let!(:owner_entity_user) { create(:entity_user, :owner, entity: entity, user: owner) }

      it "still creates the document" do
        expect {
          described_class.call(entity: entity, current_user: owner, document_params: document_params)
        }.to change(Document, :count).by(1)
      end
    end
  end
end
