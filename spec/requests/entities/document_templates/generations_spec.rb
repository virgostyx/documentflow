# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities::DocumentTemplates::Generations", type: :request do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:department) { create(:department, entity: entity) }
  let(:member_user) { create(:user, email: "member@example.com") }
  let(:sender) { create(:contact, entity: entity) }
  let(:addressee) { create(:contact, entity: entity) }

  let!(:member_membership) do
    eu = create(:entity_user, entity: entity, user: member_user, role: "member", status: "active")
    create(:entity_user_department, entity_user: eu, department: department)
    eu
  end

  let!(:document_template) do
    create(
      :document_template,
      entity: entity, created_by: member_user, name: "VAT exemption",
      subject_template: "VAT exemption request - {{supplier}}"
    )
  end

  before { sign_in member_user }

  describe "GET /entities/:entity_id/document_templates/:document_template_id/generation/new" do
    it "renders the dynamic generation form" do
      get new_entity_document_template_generation_path(entity, document_template)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Supplier")
      expect(response.body).to include("Amount")
    end

    it "renders a CC recipients multi-select listing the entity's users and contacts" do
      cc_user = create(:user, first_name: "Colleague", last_name: "Smith")
      create(:entity_user, entity: entity, user: cc_user, status: "active")
      cc_contact = create(:contact, entity: entity, first_name: "External", last_name: "Watcher")

      get new_entity_document_template_generation_path(entity, document_template)

      expect(response.body).to include('name="document[cc_party_tokens][]"')
      expect(response.body).to include(cc_user.display_name)
      expect(response.body).to include(cc_contact.display_name)
    end

    it "renders an annexes file input" do
      get new_entity_document_template_generation_path(entity, document_template)

      expect(response.body).to include('name="document[annexes][]"')
    end

    it "renders an expects_response checkbox and response_deadline field" do
      get new_entity_document_template_generation_path(entity, document_template)

      expect(response.body).to include('name="document[expects_response]"')
      expect(response.body).to include('name="document[response_deadline]"')
    end
  end

  describe "POST /entities/:entity_id/document_templates/:document_template_id/generation" do
    let(:generation_params) do
      {
        document: {
          department_id: department.id,
          document_date: Date.current,
          sender_token: "Contact-#{sender.id}",
          addressee_token: "Contact-#{addressee.id}"
        },
        field_values: {
          "supplier" => "Acme Corp",
          "amount" => "1200 EUR"
        }
      }
    end

    context "with all required fields provided" do
      it "creates a document" do
        expect {
          post entity_document_template_generation_path(entity, document_template), params: generation_params
        }.to change(Document, :count).by(1)
      end

      it "renders the document with the rendered subject and generated PDF" do
        post entity_document_template_generation_path(entity, document_template), params: generation_params

        document = entity.documents.last
        expect(document.subject).to eq("VAT exemption request - Acme Corp")
        expect(document.main_file).to be_attached
      end

      it "redirects to the created document" do
        post entity_document_template_generation_path(entity, document_template), params: generation_params

        document = entity.documents.last
        expect(response).to redirect_to(entity_document_path(entity, document))
      end
    end

    context "with cc recipients selected" do
      let(:cc_user) { create(:user) }
      let(:cc_contact) { create(:contact, entity: entity) }
      let(:generation_params) do
        {
          document: {
            department_id: department.id,
            document_date: Date.current,
            sender_token: "Contact-#{sender.id}",
            addressee_token: "Contact-#{addressee.id}",
            cc_party_tokens: [ "User-#{cc_user.id}", "Contact-#{cc_contact.id}" ]
          },
          field_values: { "supplier" => "Acme Corp", "amount" => "1200 EUR" }
        }
      end

      before { create(:entity_user, entity: entity, user: cc_user, status: "active") }

      it "creates the corresponding cc_recipients on the generated document" do
        post entity_document_template_generation_path(entity, document_template), params: generation_params

        document = entity.documents.last
        expect(document.cc_recipients.map(&:party)).to contain_exactly(cc_user, cc_contact)
      end
    end

    context "when expects_response and response_deadline are provided" do
      let(:generation_params) do
        {
          document: {
            department_id: department.id,
            document_date: Date.current,
            sender_token: "Contact-#{sender.id}",
            addressee_token: "Contact-#{addressee.id}",
            expects_response: "1",
            response_deadline: 5.days.from_now.to_date
          },
          field_values: { "supplier" => "Acme Corp", "amount" => "1200 EUR" }
        }
      end

      it "sets expects_response and response_deadline on the generated document" do
        post entity_document_template_generation_path(entity, document_template), params: generation_params

        document = entity.documents.last
        expect(document.expects_response).to be(true)
        expect(document.response_deadline).to eq(5.days.from_now.to_date)
      end
    end

    context "with annex files attached" do
      let(:generation_params) do
        {
          document: {
            department_id: department.id,
            document_date: Date.current,
            sender_token: "Contact-#{sender.id}",
            addressee_token: "Contact-#{addressee.id}",
            annexes: [ fixture_file_upload("sample.pdf", "application/pdf"), fixture_file_upload("sample.pdf", "application/pdf") ]
          },
          field_values: { "supplier" => "Acme Corp", "amount" => "1200 EUR" }
        }
      end

      it "creates one annex per attached file on the generated document" do
        post entity_document_template_generation_path(entity, document_template), params: generation_params

        document = entity.documents.last
        expect(document.annexes.count).to eq(2)
      end
    end

    context "when a required field is missing" do
      let(:generation_params) do
        {
          document: {
            department_id: department.id,
            document_date: Date.current,
            sender_token: "Contact-#{sender.id}",
            addressee_token: "Contact-#{addressee.id}"
          },
          field_values: { "supplier" => "Acme Corp" }
        }
      end

      it "does not create a document" do
        expect {
          post entity_document_template_generation_path(entity, document_template), params: generation_params
        }.not_to change(Document, :count)
      end

      it "re-renders the form with an error" do
        post entity_document_template_generation_path(entity, document_template), params: generation_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash.now[:alert]).to include("Amount")
      end
    end

    context "when the template uses the reserved {{date}} tag" do
      let!(:document_template) do
        create(
          :document_template,
          entity: entity, created_by: member_user, name: "Notice",
          subject_template: "Notice - {{supplier}}, issued {{date}}"
        )
      end

      it "does not render a field for the reserved tag" do
        get new_entity_document_template_generation_path(entity, document_template)

        expect(response.body).to include("Supplier")
        expect(response.body).not_to include('name="field_values[date]"')
      end

      it "generates the document with the date auto-substituted, without a \"date\" field_values key" do
        post entity_document_template_generation_path(entity, document_template), params: generation_params

        document = entity.documents.last
        expect(document.subject).to eq("Notice - Acme Corp, issued #{I18n.l(Date.current)}")
      end
    end

    context "when submitting an unknown field_values key" do
      let(:generation_params) do
        {
          document: {
            department_id: department.id,
            document_date: Date.current,
            sender_token: "Contact-#{sender.id}",
            addressee_token: "Contact-#{addressee.id}"
          },
          field_values: { "supplier" => "Acme Corp", "amount" => "1200 EUR", "admin" => "true" }
        }
      end

      it "ignores the unknown key without raising" do
        expect {
          post entity_document_template_generation_path(entity, document_template), params: generation_params
        }.to change(Document, :count).by(1)
      end
    end
  end
end
