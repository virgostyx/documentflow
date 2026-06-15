require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
  end

  describe "factory" do
    it "generates a valid user" do
      expect(build(:user)).to be_valid
    end

    it "is not a super admin by default" do
      expect(build(:user).super_admin).to be false
    end

    it "is a super admin with the :super_admin trait" do
      expect(build(:user, :super_admin).super_admin).to be true
    end
  end

  describe "#full_name" do
    it "concatenates first and last name" do
      user = build(:user, first_name: "Jean", last_name: "Dupont")
      expect(user.full_name).to eq("Jean Dupont")
    end
  end

  describe "Party concern" do
    subject(:user) { build(:user, first_name: "Jean", last_name: "Dupont") }

    it "exposes display_name as full_name" do
      expect(user.display_name).to eq("Jean Dupont")
    end

    it "is internal" do
      expect(user).to be_internal
      expect(user).not_to be_external
    end
  end
end
