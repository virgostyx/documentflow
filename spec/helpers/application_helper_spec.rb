# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  let(:base_classes) { "flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors" }

  describe "#nav_class" do
    def with_path(path, &)
      allow(helper).to receive(:request).and_return(double("request", path: path))
      yield
    end

    it "returns active classes on an exact path match" do
      with_path("/entities/1/documents") do
        result = helper.nav_class("/entities/1/documents")
        expect(result).to include("bg-primary-100", "text-primary-700")
      end
    end

    it "returns active classes on a sub-path (prefix) match" do
      with_path("/entities/1/documents/42") do
        result = helper.nav_class("/entities/1/documents")
        expect(result).to include("bg-primary-100", "text-primary-700")
      end
    end

    it "returns inactive classes when the path does not match" do
      with_path("/entities/1/contacts") do
        result = helper.nav_class("/entities/1/documents")
        expect(result).to include("text-gray-600", "hover:bg-primary-50", "hover:text-primary-700")
        expect(result).not_to include("bg-primary-100")
      end
    end

    it "returns active classes when any of multiple paths matches" do
      with_path("/entities/1/documents/mine") do
        result = helper.nav_class("/entities/1/documents", "/entities/1/documents/mine")
        expect(result).to include("bg-primary-100", "text-primary-700")
      end
    end

    it "includes the base classes in both active and inactive states" do
      with_path("/entities/1/contacts") do
        expect(helper.nav_class("/entities/1/documents")).to include(base_classes)
      end
    end

    describe "with exact: true" do
      it "does not match a sub-path" do
        with_path("/entities/1/documents/42") do
          result = helper.nav_class("/entities/1/documents", exact: true)
          expect(result).not_to include("bg-primary-100")
        end
      end

      it "matches the exact path itself" do
        with_path("/entities/1/documents") do
          result = helper.nav_class("/entities/1/documents", exact: true)
          expect(result).to include("bg-primary-100", "text-primary-700")
        end
      end
    end
  end

  describe "#sortable_column_header" do
    def with_request(path:, query: {})
      request_double = double("request", path: path, query_parameters: query)
      allow(helper).to receive(:request).and_return(request_double)
      yield
    end

    it "links to the same column ascending when nothing is sorted yet" do
      with_request(path: "/entities/1/documents", query: {}) do
        html = helper.sortable_column_header("Subject", "subject")
        expect(html).to include("Subject")
        expect(html).to include('href="/entities/1/documents?direction=asc&amp;sort=subject"')
      end
    end

    it "toggles to descending and shows an indicator when already sorted ascending" do
      with_request(path: "/entities/1/documents", query: { "sort" => "subject", "direction" => "asc" }) do
        html = helper.sortable_column_header("Subject", "subject")
        expect(html).to include('href="/entities/1/documents?direction=desc&amp;sort=subject"')
        expect(html).to include("▲")
      end
    end

    it "toggles back to ascending and shows an indicator when already sorted descending" do
      with_request(path: "/entities/1/documents", query: { "sort" => "subject", "direction" => "desc" }) do
        html = helper.sortable_column_header("Subject", "subject")
        expect(html).to include('href="/entities/1/documents?direction=asc&amp;sort=subject"')
        expect(html).to include("▼")
      end
    end

    it "does not show an indicator for a column that is not the current sort" do
      with_request(path: "/entities/1/documents", query: { "sort" => "subject", "direction" => "asc" }) do
        html = helper.sortable_column_header("Reference", "reference_number")
        expect(html).not_to include("▲")
        expect(html).not_to include("▼")
      end
    end

    it "preserves other query params and resets the page" do
      with_request(path: "/entities/1/documents", query: { "q" => "contract", "status" => "draft", "scope" => "mine", "page" => "3" }) do
        html = helper.sortable_column_header("Subject", "subject")
        expect(html).to include("q=contract")
        expect(html).to include("status=draft")
        expect(html).to include("scope=mine")
        expect(html).not_to include("page=")
      end
    end
  end
end
