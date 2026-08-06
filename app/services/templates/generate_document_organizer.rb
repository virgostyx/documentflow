# frozen_string_literal: true

module Templates
  class GenerateDocumentOrganizer < ApplicationService
    workflow_steps Documents::Actions::ValidateDepartmentMembership,
                   Actions::RenderTemplateText,
                   Documents::Actions::CreateDocument,
                   Actions::GenerateMainFileFromText,
                   Actions::ApplyDefaultCircuitTemplate
  end
end
