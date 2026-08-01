# frozen_string_literal: true

module SystemHelpers
  def sign_in_via_form(user, password: "password123")
    visit new_user_session_path
    fill_in "Email address", with: user.email
    fill_in "Password", with: password
    click_button "Sign in"

    if user.otp_required_for_login?
      # A 6-digit code auto-submits the form (see otp_auto_submit_controller.js),
      # which disables/removes the "Verify" button almost immediately - only
      # click it if it's still there and enabled by the time fill_in returns.
      fill_in "Authentication code", with: ROTP::TOTP.new(user.otp_secret).now
      click_button "Verify" if page.has_button?("Verify", disabled: false, wait: 0.5)
    end
  end

  def open_actions_menu
    find("summary", text: "Actions").click
  end

  def sign_out_via_ui(user)
    find("summary", text: user.email).click
    click_link "Sign out"
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
