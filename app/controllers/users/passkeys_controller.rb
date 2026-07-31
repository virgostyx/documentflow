# frozen_string_literal: true

module Users
  # Self-service management of passkeys (WebAuthn credentials). Registering
  # a user's first passkey here is what makes User#passwordless? true and
  # generates the one-time recovery codes shown once on success.
  class PasskeysController < ApplicationController
    layout "pages"

    def index
      @webauthn_credentials = current_user.webauthn_credentials.order(:created_at)
    end

    def options
      creation_options = WebAuthn::Credential.options_for_create(
        user: {
          id: current_user.webauthn_id,
          name: current_user.email,
          display_name: current_user.full_name
        },
        exclude: current_user.webauthn_credentials.pluck(:external_id),
        authenticator_selection: { resident_key: "required", user_verification: "required" }
      )
      session[:webauthn_registration_challenge] = creation_options.challenge
      render json: creation_options
    end

    def create
      nickname = params[:nickname].to_s.strip
      return render json: { error: "Please enter a name for this passkey." }, status: :unprocessable_content if nickname.blank?

      webauthn_credential = WebAuthn::Credential.from_create(params[:credential])
      webauthn_credential.verify(session.delete(:webauthn_registration_challenge), user_verification: true)

      first_passkey = current_user.webauthn_credentials.none?

      credential = current_user.webauthn_credentials.build(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        nickname: nickname
      )

      unless credential.save
        return render json: { error: credential.errors.full_messages.to_sentence }, status: :unprocessable_content
      end

      backup_codes = nil
      if first_passkey
        backup_codes = current_user.generate_otp_backup_codes!
        current_user.save!
      end

      render json: { ok: true, backup_codes: backup_codes }
    rescue WebAuthn::Error
      render json: { error: "Passkey registration failed. Please try again." }, status: :unprocessable_content
    end

    def destroy
      credential = current_user.webauthn_credentials.find(params[:id])
      credential.destroy!
      current_user.webauthn_credentials.reload

      if current_user.webauthn_credentials.none? && current_user.two_factor_required? && !current_user.otp_required_for_login?
        redirect_to two_factor_setup_path,
          alert: "Passkey removed. Your role requires two-factor authentication — please set up an authenticator app now."
      elsif current_user.webauthn_credentials.none?
        redirect_to passkeys_path, notice: "Passkey removed. Password sign-in is available for your account again."
      else
        redirect_to passkeys_path, notice: "Passkey removed."
      end
    end
  end
end
