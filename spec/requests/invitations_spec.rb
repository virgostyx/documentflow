# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations", type: :request do
  let(:entity) { create(:entity) }
  let(:inviter) { create(:user) }
  let!(:entity_user) do
    create(:entity_user, :pending, entity: entity, user: nil,
                                   invited_email: "newcomer@example.com", invited_by: inviter, role: "member")
  end

  describe "GET /invitations/:token" do
    context "with an invalid token" do
      it "redirects to root with an alert" do
        get invitation_path("invalid-token")

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when not signed in" do
      it "renders the invitation summary with a link to set up an account" do
        get invitation_path(entity_user.invitation_token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(entity.name)
        expect(response.body).to include(invitation_register_path(entity_user.invitation_token))
      end
    end

    context "when signed in with the invited email" do
      let(:existing_user) { create(:user, email: "newcomer@example.com") }

      before { sign_in existing_user }

      it "accepts the invitation and redirects to the entity" do
        get invitation_path(entity_user.invitation_token)

        expect(response).to redirect_to(entity_path(entity))
        expect(entity_user.reload).to be_active
        expect(entity_user.user).to eq(existing_user)
      end
    end

    context "when signed in with a different email" do
      let(:other_user) { create(:user, email: "someone-else@example.com") }

      before { sign_in other_user }

      it "does not accept the invitation and shows a mismatch message" do
        get invitation_path(entity_user.invitation_token)

        expect(response).to have_http_status(:ok)
        expect(entity_user.reload).to be_pending
      end
    end

    context "when the invitation was already accepted" do
      before { entity_user.update!(status: "active") }

      it "redirects to root" do
        get invitation_path(entity_user.invitation_token)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /invitations/:token/register" do
    it "renders the account setup form prefilled with the invited email" do
      get invitation_register_path(entity_user.invitation_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("newcomer@example.com")
    end

    context "when already signed in" do
      before { sign_in create(:user) }

      it "redirects to the invitation show page" do
        get invitation_register_path(entity_user.invitation_token)

        expect(response).to redirect_to(invitation_path(entity_user.invitation_token))
      end
    end
  end

  describe "POST /invitations/:token/register" do
    let(:valid_params) do
      {
        user: {
          first_name: "Jean", last_name: "Dupont",
          password: "Password123!", password_confirmation: "Password123!"
        }
      }
    end

    it "creates the user, signs them in, and accepts the invitation" do
      expect {
        post invitation_create_account_path(entity_user.invitation_token), params: valid_params
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(entity_path(entity))

      entity_user.reload
      expect(entity_user).to be_active
      expect(entity_user.user.email).to eq("newcomer@example.com")
    end

    context "with invalid password confirmation" do
      let(:invalid_params) do
        {
          user: {
            first_name: "Jean", last_name: "Dupont",
            password: "Password123!", password_confirmation: "Mismatch123!"
          }
        }
      end

      it "re-renders the registration form with errors" do
        expect {
          post invitation_create_account_path(entity_user.invitation_token), params: invalid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(entity_user.reload).to be_pending
      end
    end
  end
end
