# frozen_string_literal: true

# Signs/verifies the short-lived token Collabora Online passes back on every
# WOPI call (as `access_token`). Collabora talks to these endpoints
# server-to-server, not through the browser session, so this token stands in
# for Devise authentication; live document lock state (see Wopi::FilesController)
# is what actually authorizes each action, not the token's mere validity.
module Wopi
  class AccessToken
    DEFAULT_TTL = 4.hours

    Payload = Struct.new(:document_id, :user_id, :expires_at, keyword_init: true) do
      def expired?
        expires_at.nil? || Time.current > expires_at
      end
    end

    def self.verifier
      Rails.application.message_verifier("wopi_access_token")
    end

    def self.encode(document:, user:, ttl: DEFAULT_TTL)
      verifier.generate(
        { document_id: document.id, user_id: user.id, expires_at: ttl.from_now },
        expires_in: ttl
      )
    end

    # Returns a Payload, or nil if the token is missing, tampered with, or expired.
    def self.decode(token)
      return nil if token.blank?

      data = verifier.verify(token)
      payload = Payload.new(**data)
      payload.expired? ? nil : payload
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
  end
end
