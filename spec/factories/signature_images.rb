FactoryBot.define do
  factory :signature_image do
    association :user
    image_data { Base64.strict_encode64(Rails.root.join("spec/fixtures/files/logo.png").binread) }
    content_type { "image/png" }
    byte_size { Rails.root.join("spec/fixtures/files/logo.png").binread.bytesize }
  end
end
