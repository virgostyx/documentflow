# Warden performs "opportunistic" authentication: any call to
# `user_signed_in?`/`current_user` for a not-yet-authenticated scope makes
# Warden silently try to authenticate using whatever's in the *current*
# request's params - including on the sign-in POST itself, before the
# controller action ever runs (see ApplicationController#enforce_two_factor_setup,
# whose harmless-looking `user_signed_in?` check triggers this).
#
# devise-two-factor's strategy treats "no OTP required" as "password alone
# is enough" (see #validate_otp below). Passwordless (WebAuthn) accounts
# never set otp_required_for_login, so without this patch their old
# password would silently sign them in via that side channel, bypassing
# Users::SessionsController#create's explicit passwordless? check entirely.
Rails.application.config.to_prepare do
  Devise::Strategies::TwoFactorAuthenticatable.prepend(
    Module.new do
      def validate_otp(resource)
        return false if resource.passwordless?

        super
      end
    end
  )
end
