# frozen_string_literal: true

module Users
  # Last-resort sign-in for a passwordless user who lost their only passkey.
  # Reuses the existing :two_factor_backupable codes rather than a separate
  # recovery mechanism - gated on passwordless? so a legacy TOTP-only user's
  # backup codes (meant for the OTP challenge) can't be replayed here to
  # bypass password+TOTP on an account that never went passwordless.
  class RecoveryCodeSessionsController < ApplicationController
    layout "pages"
    skip_before_action :authenticate_user!
    skip_before_action :enforce_two_factor_setup

    def new
    end

    def create
      user = User.find_by(email: params[:email].to_s.strip)

      if user&.passwordless? && user.invalidate_otp_backup_code!(params[:recovery_code].to_s.strip)
        sign_in(user)
        redirect_to passkeys_path,
          notice: "Signed in with a recovery code. Since your passkey is no longer available, please remove it and register a new one now."
      else
        flash.now[:alert] = "Invalid email or recovery code."
        render :new, status: :unprocessable_content
      end
    end
  end
end
