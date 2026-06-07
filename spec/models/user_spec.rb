require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
  end

  describe "factory" do
    it "génère un utilisateur valide" do
      expect(build(:user)).to be_valid
    end

    it "n'est pas super admin par défaut" do
      expect(build(:user).super_admin).to be false
    end

    it "est super admin avec le trait :super_admin" do
      expect(build(:user, :super_admin).super_admin).to be true
    end
  end
end
