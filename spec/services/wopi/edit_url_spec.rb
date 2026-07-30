# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wopi::EditUrl do
  let(:document) { create(:document, :with_workflow, :in_progress) }
  let(:user) { document.created_by }

  describe ".for" do
    context "when Collabora has an editor for the document's content type" do
      before do
        allow(Wopi::Discovery).to receive(:edit_url_template)
          .with(content_type: "application/pdf")
          .and_return("https://office.example.com/browser/1234/cool.html?")
      end

      it "builds an edit URL with the WOPISrc and a fresh access token" do
        url = described_class.for(document: document, user: user)

        expect(url).to start_with("https://office.example.com/browser/1234/cool.html?")
        expect(url).to include("WOPISrc=")
        expect(url).to include("access_token=")
      end

      it "embeds a WOPISrc that Wopi::AccessToken can be exchanged against" do
        url = described_class.for(document: document, user: user)
        token = CGI.parse(URI.parse(url).query)["access_token"].first

        payload = Wopi::AccessToken.decode(token)
        expect(payload.document_id).to eq(document.id)
        expect(payload.user_id).to eq(user.id)
      end
    end

    context "when Collabora has no editor for the document's content type" do
      before { allow(Wopi::Discovery).to receive(:edit_url_template).and_return(nil) }

      it "returns nil" do
        expect(described_class.for(document: document, user: user)).to be_nil
      end
    end

    context "when the document has no main file attached" do
      before { document.main_file.purge }

      it "returns nil without calling Collabora" do
        expect(Wopi::Discovery).not_to receive(:edit_url_template)

        expect(described_class.for(document: document, user: user)).to be_nil
      end
    end
  end
end
