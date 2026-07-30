# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wopi::AccessToken do
  let(:document) { create(:document) }
  let(:user) { create(:user) }

  describe ".encode / .decode" do
    it "round-trips the document and user ids" do
      token = described_class.encode(document: document, user: user)
      payload = described_class.decode(token)

      expect(payload.document_id).to eq(document.id)
      expect(payload.user_id).to eq(user.id)
    end

    it "returns nil for a tampered token" do
      token = described_class.encode(document: document, user: user)

      expect(described_class.decode("#{token}tampered")).to be_nil
    end

    it "returns nil for a blank token" do
      expect(described_class.decode(nil)).to be_nil
      expect(described_class.decode("")).to be_nil
    end

    it "returns nil once the token has expired" do
      token = described_class.encode(document: document, user: user, ttl: 1.minute)

      travel_to 2.minutes.from_now do
        expect(described_class.decode(token)).to be_nil
      end
    end
  end
end
