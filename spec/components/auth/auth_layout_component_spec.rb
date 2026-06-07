require "rails_helper"

RSpec.describe Auth::AuthLayoutComponent, type: :component do
  subject do
    render_inline(described_class.new(title: "Connexion", subtitle: "Heureux de vous revoir")) do
      "<p>Contenu du formulaire</p>".html_safe
    end
  end

  it "affiche le titre" do
    expect(subject).to have_text("Connexion")
  end

  it "affiche le sous-titre" do
    expect(subject).to have_text("Heureux de vous revoir")
  end

  it "affiche le contenu du bloc" do
    expect(subject).to have_text("Contenu du formulaire")
  end

  it "affiche le panneau de marque sky blue" do
    expect(subject).to have_css(".bg-primary-600, .from-primary-600")
  end
end
