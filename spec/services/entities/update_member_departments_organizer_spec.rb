# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entities::UpdateMemberDepartmentsOrganizer do
  let(:entity) { create(:entity) }
  let(:owner) { create(:user) }
  let!(:owner_entity_user) { create(:entity_user, :owner, entity: entity, user: owner) }

  let(:department_a) { create(:department, entity: entity) }
  let(:department_b) { create(:department, entity: entity) }
  let(:department_c) { create(:department, entity: entity) }

  let(:member) { create(:user) }
  let!(:member_entity_user) do
    eu = create(:entity_user, entity: entity, user: member, role: "member", status: "active")
    create(:entity_user_department, :primary, entity_user: eu, department: department_a)
    eu
  end

  describe ".call" do
    context "avec des départements valides" do
      let(:params) do
        {
          entity_user: member_entity_user, current_user: owner,
          department_ids: [ department_b.id, department_c.id ], primary_department_id: department_b.id
        }
      end

      it "remplace l'ensemble des départements assignés" do
        described_class.call(**params)

        member_entity_user.reload
        expect(member_entity_user.departments).to contain_exactly(department_b, department_c)
        expect(member_entity_user.primary_department).to eq(department_b)
      end

      it "retourne un succès" do
        result = described_class.call(**params)
        expect(result).to be_success
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(**params)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "quand aucun département n'est fourni pour un membre" do
      let(:params) do
        { entity_user: member_entity_user, current_user: owner, department_ids: [], primary_department_id: nil }
      end

      it "ne modifie pas les départements et retourne un échec" do
        result = described_class.call(**params)

        expect(result).not_to be_success
        member_entity_user.reload
        expect(member_entity_user.departments).to contain_exactly(department_a)
      end
    end

    context "quand aucun département n'est fourni pour un owner" do
      let(:params) do
        { entity_user: owner_entity_user, current_user: owner, department_ids: [], primary_department_id: nil }
      end

      it "autorise l'absence de département" do
        result = described_class.call(**params)

        expect(result).to be_success
        expect(owner_entity_user.reload.departments).to be_empty
      end
    end
  end
end
