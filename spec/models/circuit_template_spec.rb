# frozen_string_literal: true

require "rails_helper"

RSpec.describe CircuitTemplate, type: :model do
  let(:entity) { create(:entity) }

  subject(:circuit_template) { build(:circuit_template, entity: entity) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to have_many(:circuit_template_steps).dependent(:destroy) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "validates uniqueness of name scoped to entity" do
      create(:circuit_template, entity: entity, name: "Standard circuit")

      duplicate = build(:circuit_template, entity: entity, name: "Standard circuit")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same name in a different entity" do
      create(:circuit_template, entity: entity, name: "Standard circuit")

      other_entity = create(:entity)
      other_template = build(:circuit_template, entity: other_entity, name: "Standard circuit")
      expect(other_template).to be_valid
    end
  end

  # ── Nested attributes ────────────────────────────────────────────────────

  describe "nested attributes" do
    it "builds and persists circuit template steps" do
      circuit_template.circuit_template_steps_attributes = [
        { role: "RED", order: 1 },
        { role: "VISA", order: 2 }
      ]
      circuit_template.save!

      expect(circuit_template.circuit_template_steps.count).to eq(2)
    end

    it "destroys steps marked for destruction" do
      circuit_template.save!
      step = create(:circuit_template_step, circuit_template: circuit_template, order: 1)

      circuit_template.circuit_template_steps_attributes = [ { id: step.id, _destroy: "1" } ]
      circuit_template.save!

      expect(circuit_template.circuit_template_steps.reload).to be_empty
    end
  end

  # ── Ordering ──────────────────────────────────────────────────────────────

  describe "#circuit_template_steps" do
    it "returns steps ordered by their position" do
      circuit_template.save!
      step2 = create(:circuit_template_step, circuit_template: circuit_template, order: 2, role: "VISA")
      step1 = create(:circuit_template_step, circuit_template: circuit_template, order: 1, role: "RED")

      expect(circuit_template.circuit_template_steps.to_a).to eq([ step1, step2 ])
    end
  end
end
