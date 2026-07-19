# frozen_string_literal: true

FactoryBot.define do
  factory :annex do
    association :document

    after(:build) do |annex|
      annex.file.attach(io: StringIO.new("content"), filename: "annex.pdf", content_type: "application/pdf") unless annex.file.attached?
    end
  end
end
