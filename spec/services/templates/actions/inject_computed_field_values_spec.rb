# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::Actions::InjectComputedFieldValues do
  let(:ctx) do
    LightService::Context.make(field_values: field_values, document_params: document_params)
  end

  describe ".execute" do
    context "with a valid document_date" do
      let(:field_values) { { "supplier" => "Acme Corp" } }
      let(:document_params) { { department_id: 1, document_date: "2026-08-06" } }

      it "injects the formatted date under the reserved \"date\" key" do
        result = described_class.execute(ctx)
        expect(result.field_values["date"]).to eq(I18n.l(Date.new(2026, 8, 6)))
      end

      it "preserves the other field_values already present" do
        result = described_class.execute(ctx)
        expect(result.field_values["supplier"]).to eq("Acme Corp")
      end

      it "succeeds" do
        result = described_class.execute(ctx)
        expect(result).to be_success
      end
    end

    context "when field_values is nil" do
      let(:field_values) { nil }
      let(:document_params) { { document_date: "2026-08-06" } }

      it "still injects the date" do
        result = described_class.execute(ctx)
        expect(result.field_values["date"]).to eq(I18n.l(Date.new(2026, 8, 6)))
      end
    end

    context "when document_date is blank" do
      let(:field_values) { {} }
      let(:document_params) { { document_date: "" } }

      it "injects an empty string instead of raising" do
        result = described_class.execute(ctx)
        expect(result.field_values["date"]).to eq("")
      end

      it "succeeds (the missing document_date is caught later by Document validation)" do
        result = described_class.execute(ctx)
        expect(result).to be_success
      end
    end

    context "when document_date is not a parseable date" do
      let(:field_values) { {} }
      let(:document_params) { { document_date: "not-a-date" } }

      it "injects an empty string instead of raising" do
        result = described_class.execute(ctx)
        expect(result.field_values["date"]).to eq("")
      end
    end
  end
end
