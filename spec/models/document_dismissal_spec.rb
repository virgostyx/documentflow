# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentDismissal, type: :model do
  subject(:dismissal) { build(:document_dismissal) }

  describe "associations" do
    it { is_expected.to belong_to(:document) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:tab).in_array(%w[waiting info]) }

    it "is invalid when the same document/user/tab combination already exists" do
      document = create(:document)
      user = create(:user)
      create(:document_dismissal, document: document, user: user, tab: "waiting")

      expect { create(:document_dismissal, document: document, user: user, tab: "waiting") }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
