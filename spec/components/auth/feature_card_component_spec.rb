require "rails_helper"

RSpec.describe Auth::FeatureCardComponent, type: :component do
  subject do
    render_inline(described_class.new(
      icon: '<path d="M3 3h18v18H3z"/>',
      title: "Workflow structuré",
      description: "RED → VISA → SIGN → EXP"
    ))
  end

  it "affiche le titre" do
    expect(subject).to have_text("Workflow structuré")
  end

  it "affiche la description" do
    expect(subject).to have_text("RED → VISA → SIGN → EXP")
  end

  it "affiche l'icône dans un badge sky blue" do
    expect(subject).to have_css(".bg-primary-100 svg path")
  end
end
