# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::RenderEmailBody do
  let(:entity) { create(:entity) }
  let(:email_template) do
    create(:email_template, entity: entity, body_template: "Dear {{recipient_name}}, reference {{reference}}, issued {{date}}.")
  end

  describe ".call" do
    context "when all required fields are provided" do
      it "substitutes the ordinary tags with the given field values" do
        result = described_class.call(email_template: email_template, field_values: { "reference" => "TND-2026-01" })

        expect(result.body).to include("reference TND-2026-01")
      end

      it "resolves the reserved {{date}} tag to today's date" do
        result = described_class.call(email_template: email_template, field_values: { "reference" => "TND-2026-01" })

        expect(result.body).to include(I18n.l(Date.current))
      end

      it "leaves the reserved {{recipient_name}} tag literal for later per-recipient resolution" do
        result = described_class.call(email_template: email_template, field_values: { "reference" => "TND-2026-01" })

        expect(result.body).to include("Dear {{recipient_name}}")
      end

      it "reports success" do
        result = described_class.call(email_template: email_template, field_values: { "reference" => "TND-2026-01" })

        expect(result).to be_success
      end
    end

    context "when the template has a subject_template" do
      let(:email_template) do
        create(:email_template, entity: entity,
          subject_template: "Tender {{reference}} - {{recipient_name}}",
          body_template: "Dear {{recipient_name}}, reference {{reference}}.")
      end

      it "substitutes ordinary tags in the subject" do
        result = described_class.call(email_template: email_template, field_values: { "reference" => "TND-2026-01" })

        expect(result.subject).to include("Tender TND-2026-01")
      end

      it "leaves the reserved {{recipient_name}} tag literal in the subject too" do
        result = described_class.call(email_template: email_template, field_values: { "reference" => "TND-2026-01" })

        expect(result.subject).to include("{{recipient_name}}")
      end
    end

    context "when the template has no subject_template" do
      it "returns a nil subject" do
        result = described_class.call(email_template: email_template, field_values: { "reference" => "TND-2026-01" })

        expect(result.subject).to be_nil
      end
    end

    context "when a required field is missing" do
      it "does not render a body" do
        result = described_class.call(email_template: email_template, field_values: {})

        expect(result.body).to be_nil
      end

      it "reports failure with the missing field" do
        result = described_class.call(email_template: email_template, field_values: {})

        expect(result).not_to be_success
        expect(result.missing_fields.map(&:tag_name)).to contain_exactly("reference")
      end
    end

    context "when field_values is nil" do
      it "treats it as an empty hash and reports the missing required field" do
        result = described_class.call(email_template: email_template, field_values: nil)

        expect(result).not_to be_success
      end
    end
  end
end
