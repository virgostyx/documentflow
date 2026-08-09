# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ModelRegistry do
  describe ".display_name" do
    it "humanizes and pluralizes a CamelCase model name with spacing" do
      expect(described_class.display_name("WebauthnCredential")).to eq("Webauthn credentials")
    end

    it "handles a single-word model name" do
      expect(described_class.display_name("Department")).to eq("Departments")
    end
  end
end
