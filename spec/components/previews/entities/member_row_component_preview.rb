# frozen_string_literal: true

module Entities
  class MemberRowComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def default
      entity = preview_entity
      admin = preview_user("owner@preview.example.com")
      preview_entity_user(user: admin, entity: entity, role: "admin")

      member = preview_user("member@preview.example.com")
      entity_user = preview_entity_user(user: member, entity: entity, role: "member")

      render(Entities::MemberRowComponent.new(entity_user: entity_user, current_user: admin, entity: entity))
    end

    def pending_invitation
      entity = preview_entity
      admin = preview_user("owner@preview.example.com")
      preview_entity_user(user: admin, entity: entity, role: "admin")

      entity_user = EntityUser.find_or_create_by!(entity: entity, invited_email: "invitee@preview.example.com") do |record|
        record.role = "member"
        record.status = "pending"
      end

      render(Entities::MemberRowComponent.new(entity_user: entity_user, current_user: admin, entity: entity))
    end
  end
end
