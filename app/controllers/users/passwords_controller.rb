# frozen_string_literal: true

module Users
  class PasswordsController < Devise::PasswordsController
    def create
      user = User.find_by(email: password_params[:email])

      if user&.passwordless?
        return redirect_to new_user_session_path,
          alert: "This account signs in with a passkey and has no password to reset. If you've lost your passkey, use a recovery code instead."
      end

      super
    end

    private

    def password_params
      params.require(:user).permit(:email)
    end
  end
end
