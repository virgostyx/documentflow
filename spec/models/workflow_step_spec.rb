# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkflowStep, type: :model do
  let(:document) { create(:document) }

  subject(:workflow_step) { build(:workflow_step, document: document) }

  # ── Associations ──────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:document) }
    it { is_expected.to belong_to(:actor).class_name("User").optional }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:order) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_numericality_of(:order).only_integer.is_greater_than(0) }

    describe "role inclusion" do
      %w[RED VISA SIGN EXP].each do |role|
        it "accepts #{role}" do
          workflow_step.role = role
          expect(workflow_step).to be_valid
        end
      end

      it "rejects an unknown role" do
        workflow_step.role = "REVIEW"
        expect(workflow_step).not_to be_valid
        expect(workflow_step.errors[:role]).to be_present
      end
    end

    describe "status inclusion" do
      %w[pending approved rejected skipped].each do |status|
        it "accepts #{status}" do
          workflow_step.status = status
          expect(workflow_step).to be_valid
        end
      end

      it "rejects an unknown status" do
        workflow_step.status = "in_review"
        expect(workflow_step).not_to be_valid
        expect(workflow_step.errors[:status]).to be_present
      end
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe "scopes" do
    let!(:pending_step)  { create(:workflow_step, document: document, role: "RED", order: 1, status: "pending") }
    let!(:approved_step) { create(:workflow_step, document: document, role: "VISA", order: 2, status: "approved") }
    let!(:rejected_step) { create(:workflow_step, document: document, role: "SIGN", order: 3, status: "rejected") }
    let!(:skipped_step)  { create(:workflow_step, document: document, role: "EXP", order: 4, status: "skipped") }

    describe ".pending" do
      it "returns only pending steps" do
        expect(WorkflowStep.pending).to include(pending_step)
        expect(WorkflowStep.pending).not_to include(approved_step, rejected_step, skipped_step)
      end
    end

    describe ".approved" do
      it "returns only approved steps" do
        expect(WorkflowStep.approved).to include(approved_step)
        expect(WorkflowStep.approved).not_to include(pending_step, rejected_step, skipped_step)
      end
    end

    describe ".rejected" do
      it "returns only rejected steps" do
        expect(WorkflowStep.rejected).to include(rejected_step)
        expect(WorkflowStep.rejected).not_to include(pending_step, approved_step, skipped_step)
      end
    end

    describe ".ordered" do
      it "returns steps ordered by their position" do
        expect(WorkflowStep.ordered.to_a).to eq([ pending_step, approved_step, rejected_step, skipped_step ])
      end
    end
  end

  # ── Instance methods ──────────────────────────────────────────────────────

  describe "#pending?" do
    it "returns true when status is pending" do
      expect(build(:workflow_step, status: "pending").pending?).to be true
    end

    it "returns false otherwise" do
      expect(build(:workflow_step, status: "approved").pending?).to be false
    end
  end

  describe "#approved?" do
    it "returns true when status is approved" do
      expect(build(:workflow_step, status: "approved").approved?).to be true
    end

    it "returns false otherwise" do
      expect(build(:workflow_step, status: "pending").approved?).to be false
    end
  end

  describe "#rejected?" do
    it "returns true when status is rejected" do
      expect(build(:workflow_step, status: "rejected").rejected?).to be true
    end

    it "returns false otherwise" do
      expect(build(:workflow_step, status: "pending").rejected?).to be false
    end
  end

  describe "#skipped?" do
    it "returns true when status is skipped" do
      expect(build(:workflow_step, status: "skipped").skipped?).to be true
    end

    it "returns false otherwise" do
      expect(build(:workflow_step, status: "pending").skipped?).to be false
    end
  end

  %w[RED VISA SIGN EXP].each do |role|
    describe "##{role.downcase}?" do
      it "returns true when role is #{role}" do
        expect(build(:workflow_step, role: role).public_send("#{role.downcase}?")).to be true
      end

      it "returns false otherwise" do
        other_role = (%w[RED VISA SIGN EXP] - [ role ]).first
        expect(build(:workflow_step, role: other_role).public_send("#{role.downcase}?")).to be false
      end
    end
  end

  describe "#parallel?" do
    it "returns true when is_parallel is set" do
      expect(build(:workflow_step, :parallel).parallel?).to be true
    end

    it "returns false otherwise" do
      expect(build(:workflow_step).parallel?).to be false
    end
  end
end
