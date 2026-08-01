# frozen_string_literal: true

require "rails_helper"

RSpec.describe SignatureImage, type: :model do
  subject(:signature_image) { build(:signature_image) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:content_type) }
    it { is_expected.to validate_presence_of(:byte_size) }
    it { is_expected.to validate_presence_of(:image_data) }

    it "accepts PNG and JPEG content types" do
      %w[image/png image/jpeg].each do |content_type|
        signature_image.content_type = content_type
        expect(signature_image).to be_valid
      end
    end

    it "rejects other content types" do
      signature_image.content_type = "image/svg+xml"
      expect(signature_image).not_to be_valid
      expect(signature_image.errors[:content_type]).to be_present
    end

    it "rejects a byte_size above the maximum" do
      signature_image.byte_size = SignatureImage::MAX_BYTE_SIZE + 1
      expect(signature_image).not_to be_valid
      expect(signature_image.errors[:byte_size]).to be_present
    end

    it "allows a byte_size at the maximum" do
      signature_image.byte_size = SignatureImage::MAX_BYTE_SIZE
      expect(signature_image).to be_valid
    end

    it "validates one signature image per user" do
      user = create(:user)
      create(:signature_image, user: user)

      duplicate = build(:signature_image, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end
  end

  describe "#decoded_bytes" do
    it "round-trips the original raw bytes" do
      raw_bytes = Rails.root.join("spec/fixtures/files/logo.png").binread
      signature_image.image_data = Base64.strict_encode64(raw_bytes)

      expect(signature_image.decoded_bytes).to eq(raw_bytes)
    end
  end

  describe "encryption at rest" do
    it "never stores the plaintext payload in the raw database column" do
      raw_bytes = Rails.root.join("spec/fixtures/files/logo.png").binread
      plaintext = Base64.strict_encode64(raw_bytes)

      record = create(:signature_image, image_data: plaintext)

      sql = ActiveRecord::Base.sanitize_sql([ "SELECT image_data FROM signature_images WHERE id = ?", record.id ])
      raw_column_value = ActiveRecord::Base.connection.select_value(sql)

      expect(raw_column_value).not_to eq(plaintext)
      expect(record.reload.image_data).to eq(plaintext)
    end
  end

  describe "factory" do
    it "generates a valid signature image" do
      expect(build(:signature_image)).to be_valid
    end
  end
end
