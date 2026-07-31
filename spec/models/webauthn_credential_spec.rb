require "rails_helper"

RSpec.describe WebauthnCredential, type: :model do
  describe "validations" do
    subject { build(:webauthn_credential) }

    it { should validate_presence_of(:external_id) }
    it { should validate_presence_of(:public_key) }
    it { should validate_presence_of(:nickname) }
    it { should validate_uniqueness_of(:external_id) }
    it { should validate_uniqueness_of(:nickname).scoped_to(:user_id) }
  end

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "factory" do
    it "generates a valid webauthn credential" do
      expect(build(:webauthn_credential)).to be_valid
    end
  end
end
