# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::Actions::RenderTemplateSubject do
  let(:document_template) do
    create(:document_template, subject_template: "VAT exemption request - {{supplier}}")
  end

  let(:ctx) do
    LightService::Context.make(
      document_template: document_template,
      field_values: field_values,
      document_params: { department_id: 1 }
    )
  end

  describe ".execute" do
    context "with all required fields provided" do
      let(:field_values) { { "supplier" => "Acme Corp", "amount" => "1200 EUR" } }

      it "substitutes tags in the rendered subject" do
        result = described_class.execute(ctx)
        expect(result.document_params[:subject]).to eq("VAT exemption request - Acme Corp")
      end

      it "preserves the other keys already present in document_params" do
        result = described_class.execute(ctx)
        expect(result.document_params[:department_id]).to eq(1)
      end

      it "succeeds" do
        result = described_class.execute(ctx)
        expect(result).to be_success
      end
    end

    context "when a required field is missing" do
      let(:field_values) { { "supplier" => "Acme Corp" } }

      it "fails" do
        result = described_class.execute(ctx)
        expect(result).to be_failure
      end

      it "mentions the missing field's label" do
        result = described_class.execute(ctx)
        expect(result.message).to include("Amount")
      end
    end
  end
end
