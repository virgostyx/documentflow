# frozen_string_literal: true

module Templates
  class GenerateDocumentOrganizer < ApplicationService
    workflow_steps Documents::Actions::ValidateDepartmentMembership,
                   Actions::InjectComputedFieldValues,
                   Actions::RenderTemplateSubject,
                   Documents::Actions::CreateDocument,
                   Actions::GenerateMainFileFromDocx,
                   Actions::ApplyDefaultCircuitTemplate
  end
end
