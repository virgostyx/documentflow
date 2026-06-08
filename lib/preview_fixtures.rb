# frozen_string_literal: true

# Builds idempotent fixture records for the ViewComponent preview gallery.
# Uses find_or_create_by! so reloading the gallery repeatedly does not pile up
# garbage rows in the development database.
module PreviewFixtures
  def preview_entity(name: "Preview Entity")
    Entity.find_or_create_by!(name: name) { |entity| entity.status = "active" }
  end

  def preview_user(email)
    User.find_or_create_by!(email: email) { |user| user.password = "password123" }
  end

  def preview_entity_user(user:, entity: preview_entity, role: "member")
    EntityUser.find_or_create_by!(entity: entity, user: user) do |entity_user|
      entity_user.invited_email = user.email
      entity_user.role = role
      entity_user.status = "active"
    end
  end

  def preview_contact(first_name:, last_name:, entity: preview_entity)
    Contact.find_or_create_by!(entity: entity, first_name: first_name, last_name: last_name) do |contact|
      contact.email = "#{first_name.downcase}.#{last_name.downcase}@preview.example.com"
    end
  end

  def preview_document(subject:, status: "draft", with_workflow: false)
    entity = preview_entity

    document = Document.find_or_create_by!(entity: entity, subject: subject) do |doc|
      doc.created_by = preview_user("owner@preview.example.com")
      doc.sender = preview_contact(first_name: "Alice", last_name: "Sender", entity: entity)
      doc.addressee = preview_contact(first_name: "Bob", last_name: "Addressee", entity: entity)
      doc.document_date = Date.current
      doc.status = status
    end

    build_preview_workflow(document) if with_workflow && document.workflow_steps.none?

    document
  end

  private

  def build_preview_workflow(document)
    actors = {
      "RED" => document.created_by,
      "VISA" => preview_user("visa.actor@preview.example.com"),
      "SIGN" => preview_user("sign.actor@preview.example.com"),
      "EXP" => preview_user("exp.actor@preview.example.com")
    }
    statuses = { "RED" => "approved", "VISA" => "pending", "SIGN" => "pending", "EXP" => "pending" }

    WorkflowStep::ROLES.each_with_index do |role, index|
      document.workflow_steps.create!(role: role, order: index + 1, status: statuses[role], actor: actors[role])
    end
  end
end
