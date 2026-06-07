require "rails_helper"

RSpec.describe FlashMessageComponent, type: :component do
  it "affiche le message" do
    render_inline(described_class.new(type: :notice, message: "Document créé"))

    expect(page).to have_text("Document créé")
  end

  it "applique le style vert pour un notice" do
    render_inline(described_class.new(type: :notice, message: "OK"))

    expect(page).to have_css(".bg-green-50")
  end

  it "applique le style rouge pour une error" do
    render_inline(described_class.new(type: :error, message: "Erreur"))

    expect(page).to have_css(".bg-red-50")
  end

  it "retombe sur le style info pour un type inconnu" do
    render_inline(described_class.new(type: :unknown, message: "Hmm"))

    expect(page).to have_css(".bg-blue-50")
  end

  it "inclut une barre de progression avec la durée fournie" do
    render_inline(described_class.new(type: :notice, message: "OK", duration: 3000))

    expect(page).to have_css("[data-flash-duration-value='3000']")
  end
end
