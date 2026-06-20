# frozen_string_literal: true

require "rails_helper"

RSpec.describe PartyOptionsHelper, type: :helper do
  let(:entity) { create(:entity) }

  describe "#party_internal_options" do
    it "lists only active internal users, excluding external contacts" do
      user = create(:user, first_name: "Alice", last_name: "Martin")
      create(:entity_user, entity: entity, user: user, status: "active")
      create(:contact, entity: entity, first_name: "Bob", last_name: "Smith")

      html = helper.party_internal_options(entity)

      expect(html).to include("Alice Martin")
      expect(html).to include("value=\"User-#{user.id}\"")
      expect(html).not_to include("Bob Smith")
    end

    it "excludes non-active entity memberships" do
      pending_user = create(:user, first_name: "Pending", last_name: "User")
      create(:entity_user, entity: entity, user: pending_user, status: "pending")

      html = helper.party_internal_options(entity)

      expect(html).not_to include("Pending User")
    end

    it "marks the selected option" do
      user = create(:user)
      create(:entity_user, entity: entity, user: user, status: "active")

      html = helper.party_internal_options(entity, "User-#{user.id}")

      expect(html).to include("selected")
    end
  end

  describe "#party_grouped_options" do
    it "groups internal users and external contacts into separate optgroups" do
      user = create(:user, first_name: "Alice", last_name: "Martin")
      create(:entity_user, entity: entity, user: user, status: "active")
      contact = create(:contact, entity: entity, first_name: "Bob", last_name: "Smith")

      html = helper.party_grouped_options(entity)

      expect(html).to include('<optgroup label="Internal users">')
      expect(html).to include("Alice Martin")
      expect(html).to include("value=\"User-#{user.id}\"")
      expect(html).to include('<optgroup label="External contacts">')
      expect(html).to include("Bob Smith")
      expect(html).to include("value=\"Contact-#{contact.id}\"")
    end


    it "excludes non-active entity memberships" do
      pending_user = create(:user, first_name: "Pending", last_name: "User")
      create(:entity_user, entity: entity, user: pending_user, status: "pending")

      html = helper.party_grouped_options(entity)

      expect(html).not_to include("Pending User")
    end

    it "marks the selected option" do
      contact = create(:contact, entity: entity)

      html = helper.party_grouped_options(entity, "Contact-#{contact.id}")

      expect(html).to include("selected")
    end
  end

  describe "#department_member_options" do
    it "returns [label, id] pairs for active members of the department, sorted by name" do
      department = create(:department, entity: entity)
      bob = create(:user, first_name: "Bob", last_name: "Smith")
      alice = create(:user, first_name: "Alice", last_name: "Martin")
      [ bob, alice ].each do |user|
        eu = create(:entity_user, entity: entity, user: user, status: "active")
        create(:entity_user_department, entity_user: eu, department: department)
      end

      expect(helper.department_member_options(department)).to eq(
        [ [ "Alice Martin", alice.id ], [ "Bob Smith", bob.id ] ]
      )
    end

    it "excludes members of a different department" do
      department = create(:department, entity: entity)
      other_department = create(:department, entity: entity)
      other_user = create(:user)
      eu = create(:entity_user, entity: entity, user: other_user, status: "active")
      create(:entity_user_department, entity_user: eu, department: other_department)

      expect(helper.department_member_options(department)).to be_empty
    end

    it "excludes non-active entity memberships" do
      department = create(:department, entity: entity)
      pending_user = create(:user)
      eu = create(:entity_user, entity: entity, user: pending_user, status: "pending")
      create(:entity_user_department, entity_user: eu, department: department)

      expect(helper.department_member_options(department)).to be_empty
    end

    it "returns an empty array for a blank department" do
      expect(helper.department_member_options(nil)).to eq([])
    end
  end

  describe "#party_badge" do
    it "renders an Internal badge for a user" do
      user = build(:user)
      expect(helper.party_badge(user)).to include("Internal")
    end

    it "renders an External badge for a contact" do
      contact = build(:contact)
      expect(helper.party_badge(contact)).to include("External")
    end

    it "returns nil for a blank party" do
      expect(helper.party_badge(nil)).to be_nil
    end
  end
end
