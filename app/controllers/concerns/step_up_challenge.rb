# frozen_string_literal: true

# WebAuthn "step-up" re-authentication required immediately before approving
# a SIGN workflow step. Unlike Users::PasskeySessionsController (full login),
# identity is already known here - this only proves liveness and never calls
# sign_in. A successful verification mints a short-lived, single-use,
# step-scoped token (session[:step_up_tokens]) that ApproveStepOrganizer
# checks via Workflow::Actions::ValidateStepUpChallenge.
module StepUpChallenge
  extend ActiveSupport::Concern

  STEP_UP_TOKEN_TTL = 2.minutes

  def confirm_sign
    authorize @document, :approve?
    return head :not_found unless @workflow_step.sign?

    render "workflow_steps/confirm_sign"
  end

  def step_up_options
    return head :not_found unless @workflow_step.sign?
    return render_step_up_forbidden! unless sign_step_approvable?

    request_options = WebAuthn::Credential.options_for_get(
      allow: current_user.webauthn_credentials.pluck(:external_id),
      user_verification: "required"
    )
    session[:step_up_challenge] = { "value" => request_options.challenge, "step_id" => @workflow_step.id }
    render json: request_options
  end

  def step_up_verify
    return head :not_found unless @workflow_step.sign?
    return render_step_up_forbidden! unless sign_step_approvable?

    challenge = session[:step_up_challenge]
    return invalid_step_up! unless challenge && challenge["step_id"] == @workflow_step.id

    webauthn_credential = WebAuthn::Credential.from_get(params[:credential])
    stored = current_user.webauthn_credentials.find_by(external_id: webauthn_credential.id)
    return invalid_step_up! unless stored

    asserted_handle = webauthn_credential.user_handle
    return invalid_step_up! unless asserted_handle && ActiveSupport::SecurityUtils.secure_compare(asserted_handle, current_user.webauthn_id)

    webauthn_credential.verify(
      challenge["value"],
      public_key: stored.public_key,
      sign_count: stored.sign_count,
      user_verification: true
    )

    stored.update!(sign_count: webauthn_credential.sign_count, last_used_at: Time.current)

    token = SecureRandom.hex(32)
    session[:step_up_tokens] ||= {}
    session[:step_up_tokens][@workflow_step.id.to_s] = { "token" => token, "expires_at" => STEP_UP_TOKEN_TTL.from_now.to_i }
    session.delete(:step_up_challenge)

    render json: { ok: true, step_up_token: token }
  rescue WebAuthn::SignCountVerificationError
    render json: { error: "This passkey failed a security check and can't be used. Please contact support." }, status: :unprocessable_content
  rescue WebAuthn::Error
    invalid_step_up!
  end

  private

  # Manual check (not Pundit#authorize) so JSON endpoints return a JSON
  # error instead of Pundit::NotAuthorizedError's HTML redirect.
  def sign_step_approvable?
    @workflow_step.sign? && DocumentPolicy.new(current_user, @document).approve?
  end

  def render_step_up_forbidden!
    render json: { error: "Not authorized." }, status: :forbidden
  end

  def invalid_step_up!
    render json: { error: "Verification failed. Please try again." }, status: :unprocessable_content
  end
end
