# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Signature management", type: :request do
  let(:user) { create(:user, password: "password123") }

  before { sign_in user }

  describe "GET /signature" do
    it "renders the upload form when no signature is registered" do
      get signature_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("data:image")
    end

    it "renders status without ever including the stored image bytes" do
      signature_image = create(:signature_image, user: user)

      get signature_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(signature_image.image_data)
      expect(response.body).not_to include("data:image")
    end
  end

  describe "POST /signature" do
    it "saves a valid PNG as the user's signature" do
      file = fixture_file_upload("logo.png", "image/png")

      expect {
        post signature_path, params: { signature_image: { file: file } }
      }.to change { user.reload.signature_image.present? }.from(false).to(true)

      expect(response).to redirect_to(signature_path)
      expect(user.signature_image.content_type).to eq("image/png")
    end

    it "rejects a non-image file" do
      file = fixture_file_upload("sample.pdf", "application/pdf")

      post signature_path, params: { signature_image: { file: file } }

      expect(user.reload.signature_image).to be_nil
      follow_redirect!
      expect(response.body).to include("Content type")
    end

    it "replaces the existing signature on re-upload instead of creating a second one" do
      create(:signature_image, user: user)
      file = fixture_file_upload("logo.png", "image/png")

      expect {
        post signature_path, params: { signature_image: { file: file } }
      }.not_to change(SignatureImage, :count)
    end
  end

  describe "DELETE /signature" do
    it "removes the user's signature" do
      create(:signature_image, user: user)

      expect {
        delete signature_path
      }.to change { user.reload.signature_image.present? }.from(true).to(false)

      expect(response).to redirect_to(signature_path)
    end
  end
end
