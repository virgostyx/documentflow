# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationService do
  describe ".steps" do
    it "raises NotImplementedError when not overridden in a subclass" do
      expect { described_class.steps }.to raise_error(NotImplementedError)
    end
  end
end
