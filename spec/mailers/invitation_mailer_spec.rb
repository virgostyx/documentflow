# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvitationMailer do
  let(:entity) { create(:entity) }
  let(:inviter) { create(:user) }
  let(:entity_user) do
    create(:entity_user, :pending, entity: entity, user: nil,
                                   invited_email: "nouveau@example.com", invited_by: inviter)
  end

  describe "#entity_invitation" do
    let(:mail) { described_class.entity_invitation(entity_user) }

    it "is addressed to the invited email with a subject mentioning the entity" do
      expect(mail.to).to eq([ "nouveau@example.com" ])
      expect(mail.subject).to include(entity.name)
    end

    it "mentions the entity and the role in the body" do
      expect(mail.body.encoded).to include(entity.name)
      expect(mail.body.encoded).to include(entity_user.role)
    end
  end
end
