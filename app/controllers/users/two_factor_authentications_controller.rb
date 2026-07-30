# frozen_string_literal: true

module Users
  # Second step of a two-factor login: the password has already been
  # verified by Users::SessionsController#create, which stashed the
  # pending user id in the session instead of signing them in.
  class TwoFactorAuthenticationsController < ApplicationController
    layout "pages"
    skip_before_action :authenticate_user!
    skip_before_action :enforce_two_factor_setup
    before_action :set_pending_user

    def new
    end

    def create
      if @pending_user.validate_and_consume_otp!(otp_attempt) || @pending_user.invalidate_otp_backup_code!(otp_attempt)
        session.delete(:otp_user_id)
        sign_in(@pending_user)
        redirect_to after_sign_in_path_for(@pending_user), notice: "Signed in successfully."
      else
        flash.now[:alert] = "Invalid authentication code."
        render :new, status: :unprocessable_content
      end
    end

    private

    def otp_attempt
      params[:otp_attempt].to_s
    end

    def set_pending_user
      @pending_user = User.find_by(id: session[:otp_user_id])
      redirect_to new_user_session_path, alert: "Please sign in again." unless @pending_user
    end
  end
end
