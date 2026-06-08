# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupExpiredLinksJob do
  describe "#perform" do
    it "destroys expired shared links" do
      expired_link = create(:shared_link, :expired)

      described_class.new.perform

      expect(SharedLink).not_to exist(expired_link.id)
    end

    it "keeps active shared links" do
      active_link = create(:shared_link, expires_at: 1.day.from_now)

      described_class.new.perform

      expect(SharedLink).to exist(active_link.id)
    end
  end
end
