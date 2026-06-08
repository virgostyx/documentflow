# frozen_string_literal: true

module Ui
  class DefinitionListComponentPreview < ViewComponent::Preview
    def default
      render(Ui::DefinitionListComponent.new) do |dl|
        dl.with_item(term: "Reference number") { "2026/00001" }
        dl.with_item(term: "Document date") { "June 7, 2026" }
        dl.with_item(term: "Created by") { "owner@preview.example.com" }
      end
    end
  end
end
