# frozen_string_literal: true

module SystemHelpers
  def sign_in_via_form(user, password: "password123")
    visit new_user_session_path
    fill_in "Email address", with: user.email
    fill_in "Password", with: password
    click_button "Sign in"

    if user.otp_required_for_login?
      fill_in "Authentication code", with: ROTP::TOTP.new(user.otp_secret).now
      click_button "Verify"
    end
  end

  def open_actions_menu
    find("summary", text: "Actions").click
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
