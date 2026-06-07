# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationAction do
  let(:ctx) { LightService::Context.make(user: build(:user)) }

  describe ".fail_with!" do
    it "fails the context and stores the message under the given error key" do
      described_class.fail_with!(ctx, "Invalide", :validation_error)
      expect(ctx.failure?).to be true
      expect(ctx.message).to eq("Invalide")
      expect(ctx[:validation_error]).to eq("Invalide")
    end
  end

  describe ".succeed_with!" do
    it "sets the message on the context" do
      described_class.succeed_with!(ctx, "Fait !", result: "ok")
      expect(ctx.message).to eq("Fait !")
    end

    it "sets extra data keys on the context" do
      described_class.succeed_with!(ctx, "Fait !", result: "ok", count: 3)
      expect(ctx[:result]).to eq("ok")
      expect(ctx[:count]).to eq(3)
    end
  end

  describe ".handle_error" do
    let(:error) { StandardError.new("une erreur est survenue") }

    it "fails the context with the default message when none provided" do
      described_class.handle_error(ctx, error)
      expect(ctx.failure?).to be true
      expect(ctx.message).to include("une erreur est survenue")
    end

    it "uses the custom user_message when provided" do
      described_class.handle_error(ctx, error, "Erreur personnalisée")
      expect(ctx.message).to eq("Erreur personnalisée")
    end
  end
end
