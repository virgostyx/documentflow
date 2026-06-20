# frozen_string_literal: true

# Helpers for rendering sender/addressee/CC pickers and badges that
# distinguish internal Users from external Contacts (see Party concern).
module PartyOptionsHelper
  # Builds <option> tags restricted to internal users only (e.g. for sender).
  def party_internal_options(entity, selected = nil)
    options = entity.users.merge(EntityUser.active).order(:first_name, :last_name)
                    .map { |user| [ user.display_name, "User-#{user.id}" ] }
    options_for_select(options, selected)
  end

  # Builds grouped <option> tags for a token-based <select> (party_token),
  # separating internal entity members from external contacts.
  def party_grouped_options(entity, selected = nil)
    internal = entity.users.merge(EntityUser.active).order(:first_name, :last_name)
                      .map { |user| [ user.display_name, "User-#{user.id}" ] }
    external = entity.contacts.order(:last_name, :first_name)
                      .map { |contact| [ contact.display_name, "Contact-#{contact.id}" ] }

    grouped_options_for_select({ "Internal users" => internal, "External contacts" => external }, selected)
  end

  # Returns the active members of an entity, for use as actor options on a
  # workflow step / circuit template step collection_select.
  def entity_actors(entity = current_entity)
    entity.users.merge(EntityUser.active).order(:first_name, :last_name)
  end

  # Returns [label, id] pairs for the active members of a department, for use
  # as Lead / action-assignee / info-recipient pickers on incoming mail.
  def department_member_options(department)
    return [] if department.nil?

    department.entity_users.merge(EntityUser.active).includes(:user)
              .filter_map { |entity_user| entity_user.user && [ entity_user.user.display_name, entity_user.user.id ] }
              .sort_by(&:first)
  end

  # Renders a small "Internal"/"External" badge for a party (User or Contact).
  def party_badge(party)
    return if party.nil?

    render(Ui::BadgeComponent.new(color: party.internal? ? :info : :gray)) { party.internal? ? "Internal" : "External" }
  end
end
