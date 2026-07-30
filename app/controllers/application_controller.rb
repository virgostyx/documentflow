class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  layout :resolve_layout

  before_action :authenticate_user!
  before_action :enforce_two_factor_setup
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  # Owners/admins (and super admins) must have two-factor authentication
  # configured before they can use the app; everyone else may opt in.
  def enforce_two_factor_setup
    return unless user_signed_in?
    return if devise_controller?
    return unless current_user.two_factor_required?
    return if current_user.otp_required_for_login?

    redirect_to two_factor_setup_path, alert: "Two-factor authentication is mandatory for your account. Please set it up to continue."
  end

  # Devise pages (sign in, sign up, password...) are public
  # and use the "pages" layout which doesn't assume a signed-in user.
  def resolve_layout
    devise_controller? ? "pages" : "application"
  end

  # Allow first_name/last_name on sign up and account update.
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name])
  end

  def user_not_authorized
    redirect_back fallback_location: root_path, alert: "You are not authorized to perform this action."
  end
end
