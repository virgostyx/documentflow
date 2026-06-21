# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClassificationNode, type: :model do
  let(:entity) { create(:entity) }

  subject(:node) { build(:classification_node, entity: entity, code: "1", name: "Administration") }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:entity) }
    it { is_expected.to belong_to(:parent).class_name("ClassificationNode").optional }
    it { is_expected.to have_many(:children).class_name("ClassificationNode").dependent(:restrict_with_error) }
    it { is_expected.to have_many(:documents).dependent(:restrict_with_error) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }

    it "validates uniqueness of name scoped to entity and parent" do
      create(:classification_node, entity: entity, code: "1", name: "Administration")

      duplicate = build(:classification_node, entity: entity, code: "2", name: "Administration")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same name under a different parent" do
      root_a = create(:classification_node, entity: entity, code: "1", name: "Root A")
      create(:classification_node, entity: entity, parent: root_a, code: "1.1", name: "Drafts")

      root_b = create(:classification_node, entity: entity, code: "2", name: "Root B")
      sibling = build(:classification_node, entity: entity, parent: root_b, code: "2.1", name: "Drafts")

      expect(sibling).to be_valid
    end

    it "allows the same name in a different entity" do
      create(:classification_node, entity: entity, code: "1", name: "Administration")

      other_entity = create(:entity)
      other = build(:classification_node, entity: other_entity, code: "1", name: "Administration")

      expect(other).to be_valid
    end

    it "validates uniqueness of code scoped to entity" do
      create(:classification_node, entity: entity, code: "1", name: "Administration")

      duplicate = build(:classification_node, entity: entity, code: "1", name: "Other")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to be_present
    end

    it "allows the same code in a different entity" do
      create(:classification_node, entity: entity, code: "1", name: "Administration")

      other_entity = create(:entity)
      other = build(:classification_node, entity: other_entity, code: "1", name: "Administration")

      expect(other).to be_valid
    end

    %w[0 01 1. .1 1..2 abc].each do |bad_code|
      it "rejects a code of #{bad_code.inspect} as badly formatted" do
        node.code = bad_code
        expect(node).not_to be_valid
        expect(node.errors[:code]).to be_present
      end
    end

    %w[1 12 1.2 1.2.3 1.2.3.4].each do |good_code|
      it "accepts a well-formed code of #{good_code.inspect} at the right depth" do
        candidate = build(:classification_node, entity: entity, code: good_code, name: "Node")
        # Build the required ancestor chain so code_matches_parent is satisfied.
        segments = good_code.split(".")
        parent = nil
        segments[0...-1].each_with_index do |_, i|
          ancestor_code = segments[0..i].join(".")
          parent = ClassificationNode.find_by(entity: entity, code: ancestor_code) ||
                   create(:classification_node, entity: entity, parent: parent, code: ancestor_code, name: "Ancestor #{ancestor_code}")
        end
        candidate.parent = parent

        expect(candidate).to be_valid
      end
    end

    it "is invalid when the entity does not match the parent's entity" do
      other_entity = create(:entity)
      parent = create(:classification_node, entity: other_entity, code: "1", name: "Root")
      node.parent = parent
      node.code = "1.1"

      expect(node).not_to be_valid
      expect(node.errors[:entity]).to be_present
    end

    it "is invalid when the code does not extend the parent's code" do
      parent = create(:classification_node, entity: entity, code: "1", name: "Root")
      node.parent = parent
      node.code = "2.1"

      expect(node).not_to be_valid
      expect(node.errors[:code]).to be_present
    end

    it "is invalid when the code is a single segment but a parent is present" do
      parent = create(:classification_node, entity: entity, code: "1", name: "Root")
      node.parent = parent
      node.code = "2"

      expect(node).not_to be_valid
      expect(node.errors[:code]).to be_present
    end

    it "is invalid when the code has more than one segment but no parent is present" do
      node.code = "1.1"
      expect(node).not_to be_valid
      expect(node.errors[:code]).to be_present
    end

    it "is invalid when the parent is already at the maximum depth" do
      n1 = create(:classification_node, entity: entity, code: "1", name: "L1")
      n2 = create(:classification_node, entity: entity, parent: n1, code: "1.1", name: "L2")
      n3 = create(:classification_node, entity: entity, parent: n2, code: "1.1.1", name: "L3")
      n4 = create(:classification_node, entity: entity, parent: n3, code: "1.1.1.1", name: "L4")

      node.parent = n4
      node.code = "1.1.1.1.1"

      expect(node).not_to be_valid
      expect(node.errors[:parent]).to be_present
    end

    it "is valid up to the maximum depth of 4" do
      n1 = create(:classification_node, entity: entity, code: "1", name: "L1")
      n2 = create(:classification_node, entity: entity, parent: n1, code: "1.1", name: "L2")
      n3 = create(:classification_node, entity: entity, parent: n2, code: "1.1.1", name: "L3")

      node.parent = n3
      node.code = "1.1.1.1"

      expect(node).to be_valid
    end
  end

  # ── Destroy guards ────────────────────────────────────────────────────────

  describe "destroy" do
    it "is blocked when children still reference it" do
      node.save!
      create(:classification_node, entity: entity, parent: node, code: "#{node.code}.1", name: "Child")

      expect(node.destroy).to be false
      expect(node.errors[:base]).to be_present
    end

    it "is blocked when documents still reference it" do
      node.save!
      department = create(:department, entity: entity)
      create(:document, entity: entity, department: department, classification_node: node)

      expect(node.destroy).to be false
      expect(node.errors[:base]).to be_present
    end

    it "succeeds when empty" do
      node.save!

      expect(node.destroy).to be_truthy
    end
  end

  # ── Methods ───────────────────────────────────────────────────────────────

  describe "#root?" do
    it "is true for a node with no parent" do
      expect(node).to be_root
    end

    it "is false for a child node" do
      root = create(:classification_node, entity: entity, code: "1", name: "Root")
      node.parent = root
      node.code = "1.1"

      expect(node).not_to be_root
    end
  end

  describe ".sort_by_code" do
    it "sorts numerically rather than lexicographically" do
      n10 = build(:classification_node, code: "1.10")
      n2 = build(:classification_node, code: "1.2")
      n9 = build(:classification_node, code: "1.9")
      n1 = build(:classification_node, code: "1")

      expect(described_class.sort_by_code([ n10, n2, n9, n1 ])).to eq([ n1, n2, n9, n10 ])
    end
  end
end
