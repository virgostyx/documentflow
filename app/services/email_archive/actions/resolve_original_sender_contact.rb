# frozen_string_literal: true

module EmailArchive
  module Actions
    # Finds (or creates) the Contact representing the true external sender
    # of an ingested email, scoped to the entity — the same lookup a human
    # performs today via the incoming-mail registration form's party picker.
    class ResolveOriginalSenderContact
      class << self
        def call(entity:, from_address:, from_name: nil)
          return nil if from_address.blank?

          Contact.find_by(entity: entity, email: from_address) ||
            Contact.create(entity: entity, email: from_address, **split_name(from_name, from_address))
        end

        private

        def split_name(name, email)
          if name.present?
            first, last = name.strip.split(/\s+/, 2)
            { first_name: first, last_name: last.presence || "-" }
          else
            { first_name: email.split("@").first, last_name: "-" }
          end
        end
      end
    end
  end
end
