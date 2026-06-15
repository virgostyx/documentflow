# frozen_string_literal: true

require "rails_helper"

RSpec.describe CircuitTemplateStep, type: :model do
  let(:circuit_template) { create(:circuit_template) }

  subject(:circuit_template_step) { build(:circuit_template_step, circuit_template: circuit_template) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:circuit_template) }
    it { is_expected.to belong_to(:actor).class_name("User").optional }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:order) }
    it { is_expected.to validate_numericality_of(:order).only_integer.is_greater_than(0) }

    describe "role inclusion" do
      %w[RED VISA SIGN EXP].each do |role|
        it "accepts #{role}" do
          circuit_template_step.role = role
          expect(circuit_template_step).to be_valid
        end
      end

      it "rejects an unknown role" do
        circuit_template_step.role = "REVIEW"
        expect(circuit_template_step).not_to be_valid
        expect(circuit_template_step.errors[:role]).to be_present
      end
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe ".ordered" do
    it "returns steps ordered by their position" do
      step2 = create(:circuit_template_step, circuit_template: circuit_template, order: 2, role: "VISA")
      step1 = create(:circuit_template_step, circuit_template: circuit_template, order: 1, role: "RED")

      expect(CircuitTemplateStep.ordered.to_a).to eq([ step1, step2 ])
    end
  end

  # ── Instance methods ──────────────────────────────────────────────────────

  describe "#parallel?" do
    it "returns true when is_parallel is set" do
      expect(build(:circuit_template_step, :parallel).parallel?).to be true
    end

    it "returns false otherwise" do
      expect(build(:circuit_template_step).parallel?).to be false
    end
  end
end
