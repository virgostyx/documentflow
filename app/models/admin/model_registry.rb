# frozen_string_literal: true

module Admin
  # Allowlist of models browsable (read-only) via Admin::RecordsController.
  # Deliberately excludes User, AuditLog, SignatureImage, and ActiveStorage's
  # internal tables — see docs/dev plan for the "hand-rolled admin" feature.
  module ModelRegistry
    ENTRIES = {
      "Department" => { klass: Department },
      "Contact" => { klass: Contact },
      "CircuitTemplate" => { klass: CircuitTemplate },
      "DocumentTemplate" => { klass: DocumentTemplate },
      "EmailTemplate" => { klass: EmailTemplate },
      "ClassificationNode" => { klass: ClassificationNode },
      "WorkflowStep" => { klass: WorkflowStep },
      "CcRecipient" => { klass: CcRecipient },
      "Annex" => { klass: Annex },
      "DocumentFileVersion" => { klass: DocumentFileVersion },
      "EntityUserDepartment" => { klass: EntityUserDepartment },
      "WebauthnCredential" => { klass: WebauthnCredential, redacted_columns: %w[public_key] },
      "EntityUser" => { klass: EntityUser, redacted_columns: %w[invitation_token] },
      "SharedLink" => { klass: SharedLink, redacted_columns: %w[token] }
    }.freeze

    def self.display_name(model_name)
      model_name.underscore.humanize.pluralize
    end
  end
end
