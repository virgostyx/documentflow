require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }

    describe "external_email" do
      it "is optional" do
        expect(build(:user, external_email: nil)).to be_valid
      end

      it "rejects an invalid format" do
        user = build(:user, external_email: "not-an-email")
        expect(user).not_to be_valid
        expect(user.errors[:external_email]).to be_present
      end

      it "is unique across users" do
        create(:user, external_email: "shared@outlook.com")
        duplicate = build(:user, external_email: "shared@outlook.com")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:external_email]).to be_present
      end

      it "is normalized to lowercase" do
        user = build(:user, external_email: "  Someone@Outlook.com  ")
        user.valid?
        expect(user.external_email).to eq("someone@outlook.com")
      end
    end
  end

  describe "associations" do
    subject { build(:user) }

    it { is_expected.to have_many(:distribution_lists).dependent(:destroy) }
  end

  describe "#entities" do
    it "returns entities the user is an active member of" do
      user = create(:user)
      entity = create(:entity)
      create(:entity_user, user: user, entity: entity, status: "active")

      expect(user.entities).to contain_exactly(entity)
    end

    it "excludes entities where membership is inactive" do
      user = create(:user)
      entity = create(:entity)
      create(:entity_user, user: user, entity: entity, status: "suspended")

      expect(user.entities).to be_empty
    end
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

  describe "#two_factor_required?" do
    it "is false for a plain member" do
      user = create(:user)
      create(:entity_user, user: user, role: "member", status: "active")

      expect(user).not_to be_two_factor_required
    end

    it "is true for a super admin" do
      user = create(:user, :super_admin)

      expect(user).to be_two_factor_required
    end

    it "is true for an active owner of an entity" do
      user = create(:user)
      create(:entity_user, :owner, user: user, status: "active")

      expect(user).to be_two_factor_required
    end

    it "is true for an active admin of an entity" do
      user = create(:user)
      create(:entity_user, :admin, user: user, status: "active")

      expect(user).to be_two_factor_required
    end

    it "is false for a pending admin membership" do
      user = create(:user)
      create(:entity_user, :admin, :pending, user: user)

      expect(user).not_to be_two_factor_required
    end

    it "is false for a suspended owner membership" do
      user = create(:user)
      create(:entity_user, :owner, :suspended, user: user)

      expect(user).not_to be_two_factor_required
    end

    it "is false for a guest" do
      user = create(:user)
      create(:entity_user, :guest, user: user, status: "active")

      expect(user).not_to be_two_factor_required
    end
  end

  describe "#passwordless?" do
    it "is false when the user has no webauthn credentials" do
      expect(create(:user)).not_to be_passwordless
    end

    it "is true when the user has at least one webauthn credential" do
      user = create(:user)
      create(:webauthn_credential, user: user)

      expect(user).to be_passwordless
    end
  end

  describe "#webauthn_id" do
    it "lazily generates and persists a stable user handle" do
      user = create(:user)
      expect(user[:webauthn_id]).to be_nil

      id = user.webauthn_id
      expect(id).to be_present
      expect(user.reload[:webauthn_id]).to eq(id)
      expect(user.webauthn_id).to eq(id)
    end
  end
end
