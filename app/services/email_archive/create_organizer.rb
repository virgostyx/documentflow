# frozen_string_literal: true

module EmailArchive
  class CreateOrganizer < ApplicationService
    workflow_steps Actions::ResolveDepartment,
                   Actions::ResolveSenderUser,
                   Actions::ResolveExternalAddressee,
                   Actions::CreateArchivedDocument,
                   Actions::AttachEmailContent,
                   Actions::CreateCcRecipients,
                   Documents::Actions::BroadcastDocumentRow
  end
end
