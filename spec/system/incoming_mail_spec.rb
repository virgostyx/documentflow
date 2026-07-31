# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Incoming mail", type: :system, js: true do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:department) { create(:department, entity: entity, name: "Finance") }
  let(:registrant) { create(:user) }
  let(:lead) { create(:user) }
  let(:action_user) { create(:user) }
  let(:info_user) { create(:user) }
  let!(:sender) { create(:contact, entity: entity, first_name: "Jane", last_name: "Doe") }

  before do
    [ registrant, lead, action_user, info_user ].each do |member|
      eu = create(:entity_user, entity: entity, user: member, role: "member", status: "active")
      create(:entity_user_department, :primary, entity_user: eu, department: department)
    end
  end

  it "registers an incoming mail, assigns a lead, and routes it for action and info" do
    Capybara.using_session(:registrant) do
      sign_in_via_form(registrant)
      expect(page).to have_content(registrant.email)

      visit new_entity_incoming_mail_path(entity)
      expect(page).to have_content("Register incoming mail")

      fill_in "Subject", with: "Tax notice"
      expect(page).to have_field("Subject", with: "Tax notice")

      fill_in "Document date", with: Date.current
      select "Jane Doe", from: "Sender"
      expect(page).to have_select("Sender", selected: "Jane Doe")

      select lead.display_name, from: "Assign to"
      expect(page).to have_select("Assign to", selected: lead.display_name)

      click_button "Register mail"

      expect(page).to have_content("Incoming mail registered successfully")
      expect(page).to have_content("Tax notice")
    end

    Capybara.using_session(:lead) do
      sign_in_via_form(lead)
      expect(page).to have_content(lead.email)

      visit entity_incoming_mails_path(entity)
      expect(page).to have_content("Tax notice")

      find("tr", text: "Tax notice").find("a").click
      expect(page).to have_content("Tax notice")

      click_link "Route this mail"
      within("dialog") do
        select action_user.display_name, from: "Assign for action"
        fill_in "Message (optional)", with: "Please handle this by Friday"
        select info_user.display_name, from: "Info recipients (optional)"
        check "This mail expects a response"
        fill_in "Response deadline", with: Date.current + 5.days
        click_button "Route mail"
      end

      expect(page).to have_content("Mail routed successfully")
      expect(page).to have_content(action_user.display_name)
      expect(page).to have_content("Please handle this by Friday")

      visit entity_incoming_mails_path(entity)
      expect(page).not_to have_content("Tax notice")

      visit waiting_entity_documents_path(entity)
      expect(page).to have_content("Tax notice")
    end

    Capybara.using_session(:action_user) do
      sign_in_via_form(action_user)
      expect(page).to have_content(action_user.email)

      visit todo_entity_documents_path(entity)
      expect(page).to have_content("Tax notice")
      expect(page).to have_link(href: entity_incoming_mail_path(entity, Document.find_by!(subject: "Tax notice")))
    end

    Capybara.using_session(:info_user) do
      sign_in_via_form(info_user)
      expect(page).to have_content(info_user.email)

      visit info_entity_documents_path(entity)
      expect(page).to have_content("Tax notice")
    end
  end
end
