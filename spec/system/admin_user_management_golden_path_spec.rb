# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin user management golden path", type: :system, js: true do
  let(:super_admin) do
    create(:user, :super_admin, otp_required_for_login: true, otp_secret: User.generate_otp_secret)
  end

  it "lets a super admin revoke another super admin's access through the confirm modal" do
    sign_in_via_form(super_admin)

    target = create(:user, :super_admin, first_name: "Ada", last_name: "Lovelace",
                                          otp_required_for_login: true, otp_secret: User.generate_otp_secret)

    visit admin_users_path
    click_link "Ada Lovelace"

    expect(page).to have_content("Super admin")

    click_link "Revoke super admin"

    within("dialog") do
      expect(page).to have_content("Remove super admin access from")
      click_button "Revoke"
    end

    expect(page).to have_content("Revoked super admin access from #{target.email}")
    expect(page).not_to have_content("Super admin")
    expect(target.reload.super_admin?).to be false
  end

  it "redirects a regular signed-in user away from the admin panel" do
    regular_user = create(:user)

    sign_in_via_form(regular_user)
    expect(page).to have_current_path(dashboard_path)

    visit "/admin"

    # PagesController#home ("/") redirects a signed-in visitor straight on to
    # "/dashboard" - the app-root landing page for authenticated users.
    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_content("You are not authorized to perform this action.")
  end
end
