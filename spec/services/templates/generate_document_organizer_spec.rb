# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::GenerateDocumentOrganizer do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }
  let(:user) { create(:user) }
  let(:sender) { create(:contact, entity: entity) }
  let(:addressee) { create(:contact, entity: entity) }

  let!(:entity_user) do
    eu = create(:entity_user, entity: entity, user: user, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let(:document_template) do
    create(:document_template, entity: entity, created_by: user, subject_template: "VAT exemption request - {{supplier}}")
  end

  let(:document_params) do
    {
      department_id: department.id,
      document_date: Date.current,
      sender_token: "Contact-#{sender.id}",
      addressee_token: "Contact-#{addressee.id}"
    }
  end

  let(:base_args) do
    {
      entity: entity,
      current_user: user,
      document_template: document_template,
      field_values: field_values,
      document_params: document_params
    }
  end

  describe ".call" do
    context "with all required fields provided" do
      let(:field_values) { { "supplier" => "Acme Corp", "amount" => "1200 EUR" } }

      it "creates a document with the rendered subject" do
        result = described_class.call(**base_args)

        expect(result).to be_success
        expect(result.document.subject).to eq("VAT exemption request - Acme Corp")
      end

      it "attaches the generated .docx as the document's main_file" do
        result = described_class.call(**base_args)
        expect(result.document.main_file).to be_attached
        expect(result.document.main_file.content_type).to eq(DocumentTemplate::DOCX_CONTENT_TYPE)
      end

      it "sets sender, addressee and department from document_params" do
        result = described_class.call(**base_args)

        expect(result.document.sender).to eq(sender)
        expect(result.document.addressee).to eq(addressee)
        expect(result.document.department).to eq(department)
      end

      it "creates exactly one document" do
        expect { described_class.call(**base_args) }.to change(Document, :count).by(1)
      end
    end

    context "when a required field is missing" do
      let(:field_values) { { "supplier" => "Acme Corp" } }

      it "does not create a document" do
        expect { described_class.call(**base_args) }.not_to change(Document, :count)
      end

      it "fails with a message about the missing field" do
        result = described_class.call(**base_args)
        expect(result).to be_failure
        expect(result.message).to include("Amount")
      end
    end

    context "when the template has a linked circuit template" do
      let(:field_values) { { "supplier" => "Acme Corp", "amount" => "1200 EUR" } }
      let(:circuit_template) { create(:circuit_template, entity: entity) }

      before do
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
        create(:circuit_template_step, circuit_template: circuit_template, role: "SIGN", order: 2)
        document_template.update!(circuit_template: circuit_template)
      end

      it "clones the circuit template's steps onto the generated document" do
        result = described_class.call(**base_args)

        expect(result).to be_success
        expect(result.document.workflow_steps.reload.pluck(:role, :order)).to eq([ [ "RED", 1 ], [ "SIGN", 2 ] ])
      end
    end

    context "when the template has an invalid linked circuit template (no SIGN step)" do
      let(:field_values) { { "supplier" => "Acme Corp", "amount" => "1200 EUR" } }
      let(:circuit_template) { create(:circuit_template, entity: entity) }

      before do
        create(:circuit_template_step, circuit_template: circuit_template, role: "RED", order: 1)
        document_template.update!(circuit_template: circuit_template)
      end

      it "does not create a document" do
        expect { described_class.call(**base_args) }.not_to change(Document, :count)
      end
    end

    context "when the current_user is not a member of the requested department" do
      let(:field_values) { { "supplier" => "Acme Corp", "amount" => "1200 EUR" } }
      let(:outsider) { create(:user) }

      before { create(:entity_user, entity: entity, user: outsider, role: "member", status: "active") }

      it "does not create a document" do
        expect {
          described_class.call(**base_args.merge(current_user: outsider))
        }.not_to change(Document, :count)
      end
    end
  end
end
