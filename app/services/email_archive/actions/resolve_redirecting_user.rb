# frozen_string_literal: true

module EmailArchive
  module Actions
    # Resolves the DocumentFlow user who redirected/forwarded an incoming
    # email into the archive mailbox, and confirms they're an active member
    # of the target entity with a primary department to file the mail under.
    class ResolveRedirectingUser
      class << self
        def call(entity:, relaying_address:)
          return nil if relaying_address.blank?

          user = User.find_by(external_email: relaying_address) || User.find_by(email: relaying_address)
          return nil unless user

          entity_user = EntityUser.active.find_by(entity: entity, user: user)
          return nil unless entity_user&.primary_department

          entity_user
        end
      end
    end
  end
end
