# frozen_string_literal: true

module Documents
  class DocumentStatusBadgeComponentPreview < ViewComponent::Preview
    def draft
      render(Documents::DocumentStatusBadgeComponent.new(status: "draft"))
    end

    def in_progress
      render(Documents::DocumentStatusBadgeComponent.new(status: "in_progress"))
    end

    def signed
      render(Documents::DocumentStatusBadgeComponent.new(status: "signed"))
    end

    def finalized
      render(Documents::DocumentStatusBadgeComponent.new(status: "finalized"))
    end

    def cancelled
      render(Documents::DocumentStatusBadgeComponent.new(status: "cancelled"))
    end
  end
end
