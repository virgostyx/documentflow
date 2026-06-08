# frozen_string_literal: true

module Entities
  class EntityCardComponentPreview < ViewComponent::Preview
    include PreviewFixtures

    def default
      user = preview_user("owner@preview.example.com")
      entity = preview_entity
      preview_entity_user(user: user, entity: entity, role: "owner")

      render(Entities::EntityCardComponent.new(entity: entity, current_user: user))
    end
  end
end
