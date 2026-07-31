# frozen_string_literal: true

module Users
  # Primary, passwordless sign-in via a discoverable WebAuthn credential.
  # The server doesn't know who's signing in ahead of time - the assertion's
  # userHandle resolves it. A verified passkey satisfies mandatory 2FA by
  # itself, so this never touches session[:otp_user_id]/the TOTP challenge.
  class PasskeySessionsController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :enforce_two_factor_setup

    def options
      request_options = WebAuthn::Credential.options_for_get(user_verification: "required")
      session[:webauthn_authentication_challenge] = request_options.challenge
      render json: request_options
    end

    def create
      webauthn_credential = WebAuthn::Credential.from_get(params[:credential])

      stored = WebauthnCredential.find_by(external_id: webauthn_credential.id)
      return invalid_credential! unless stored

      user = stored.user

      asserted_handle = webauthn_credential.user_handle
      return invalid_credential! unless asserted_handle && ActiveSupport::SecurityUtils.secure_compare(asserted_handle, user.webauthn_id)

      webauthn_credential.verify(
        session.delete(:webauthn_authentication_challenge),
        public_key: stored.public_key,
        sign_count: stored.sign_count,
        user_verification: true
      )

      stored.update!(sign_count: webauthn_credential.sign_count, last_used_at: Time.current)
      sign_in(user)
      render json: { redirect_to: after_sign_in_path_for(user) }
    rescue WebAuthn::SignCountVerificationError
      render json: { error: "This passkey failed a security check and can't be used. Please contact support." }, status: :unprocessable_content
    rescue WebAuthn::Error
      invalid_credential!
    end

    private

    def invalid_credential!
      render json: { error: "Passkey sign-in failed. Please try again or use a recovery code." }, status: :unprocessable_content
    end
  end
end
