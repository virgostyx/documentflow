# frozen_string_literal: true

module SharedLinks
  class RequestRenewal
    class << self
      def call(token:, email:)
        new(token: token, email: email).call
      end
    end

    def initialize(token:, email:)
      @token = token
      @email = email.to_s.strip
    end

    def call
      document = SharedLink.find_by(token: @token)&.document
      return false if document.nil?

      role, party = matching_party(document)
      return false if party.nil?
      return false unless document.claim_shared_link_renewal!

      document.active_shared_link
      notify(role, party, document)

      true
    end

    private

    def matching_party(document)
      addressee = document.addressee
      return [ :addressee, addressee ] if matches?(addressee)

      cc_recipient = document.cc_recipients.detect { |recipient| matches?(recipient.party) }
      cc_recipient ? [ :cc, cc_recipient.party ] : [ nil, nil ]
    end

    def matches?(party)
      party&.external? && party.email.casecmp?(@email)
    end

    # No signed-in user initiates a renewal request (it's a public, unauthenticated
    # flow matched by email) - attribute the resulting audit trail to the document's
    # original author instead, since AuditLog requires an actor.
    def notify(role, party, document)
      if role == :addressee
        AddresseeNotificationJob.perform_later(party.class.name, party.id, document.id, document.created_by_id)
      else
        CcNotificationJob.perform_later(party.class.name, party.id, document.id, document.created_by_id)
      end
    end
  end
end
