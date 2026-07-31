# frozen_string_literal: true

module Users
  # The password check happens here, before Devise's own strategy chain,
  # so that a correct password for a two-factor account never signs the
  # user in directly: it only earns them the OTP challenge page.
  class SessionsController < Devise::SessionsController
    def create
      user = User.find_by(email: credentials_params[:email])

      if user&.passwordless?
        return redirect_to new_user_session_path,
          alert: "This account signs in with a passkey. Use “Sign in with a passkey” below, or “Lost your passkey?” if it's no longer available."
      end

      if user&.valid_password?(credentials_params[:password]) && user.otp_required_for_login?
        session[:otp_user_id] = user.id
        redirect_to new_two_factor_authentication_path
      else
        super
      end
    end

    private

    # Named distinctly from Devise's own `sign_in_params`, which the :new
    # action relies on to build a blank resource for the form.
    def credentials_params
      params.require(:user).permit(:email, :password)
    end
  end
end
