# frozen_string_literal: true

module Users
  # Self-service enrollment/management of two-factor authentication for the
  # current user. Enforced as mandatory for owners/admins/super admins by
  # ApplicationController#enforce_two_factor_setup, which redirects here
  # until #otp_required_for_login? is true - so this controller must stay
  # reachable even while that requirement is unmet.
  class TwoFactorSetupsController < ApplicationController
    layout "pages"
    skip_before_action :enforce_two_factor_setup

    def show
      return redirect_to passkeys_path if current_user.passwordless?

      build_pending_secret unless current_user.otp_required_for_login?
    end

    def create
      secret = session[:pending_otp_secret]

      if secret.present? && valid_code?(secret, otp_attempt)
        current_user.otp_secret = secret
        current_user.otp_required_for_login = true
        @backup_codes = current_user.generate_otp_backup_codes!
        current_user.save!
        session.delete(:pending_otp_secret)
        render :backup_codes
      else
        build_pending_secret(secret)
        flash.now[:alert] = "Invalid authentication code."
        render :show, status: :unprocessable_content
      end
    end

    def backup_codes
      unless current_user.otp_required_for_login? || current_user.passwordless?
        return redirect_to(two_factor_setup_path, alert: "Set up two-factor authentication first.")
      end

      @backup_codes = current_user.generate_otp_backup_codes!
      current_user.save!
      render :backup_codes
    end

    def destroy
      if current_user.two_factor_required? && !current_user.passwordless?
        return redirect_to two_factor_setup_path,
                            alert: "Two-factor authentication is mandatory for your account and cannot be disabled."
      end

      unless current_user.valid_password?(params[:current_password].to_s)
        return redirect_to two_factor_setup_path, alert: "Incorrect password."
      end

      current_user.update!(otp_required_for_login: false, otp_secret: nil, consumed_timestep: nil, otp_backup_codes: [])
      redirect_to two_factor_setup_path, notice: "Two-factor authentication disabled."
    end

    private

    def otp_attempt
      params[:otp_attempt].to_s
    end

    def valid_code?(secret, code)
      code.present? && ROTP::TOTP.new(secret).verify(code.gsub(/\s+/, ""), drift_behind: 30, drift_ahead: 30).present?
    end

    def build_pending_secret(secret = nil)
      session[:pending_otp_secret] ||= secret || User.generate_otp_secret
      @otp_secret = session[:pending_otp_secret]
      @provisioning_uri = current_user.otp_provisioning_uri(current_user.email, issuer: "DocumentFlow", otp_secret: @otp_secret)
      @qr_code_svg = RQRCode::QRCode.new(@provisioning_uri).as_svg(module_size: 5, use_path: true, standalone: true)
    end
  end
end
