require "rails_helper"

RSpec.describe Shared::HeaderComponent, type: :component do
  let(:user) { build_stubbed(:user, email: "alice@documentflow.test") }

  subject { render_inline(described_class.new(current_user: user)) }

  it "affiche le logo DocumentFlow" do
    expect(subject).to have_text("DocumentFlow")
  end

  it "affiche l'email de l'utilisateur courant" do
    expect(subject).to have_text("alice@documentflow.test")
  end

  it "affiche un lien de déconnexion" do
    expect(subject).to have_css("a[data-turbo-method='delete']", text: /[Dd]éconnexion/)
  end

  it "est un header fixe en haut de la page" do
    expect(subject).to have_css("header.fixed.top-0")
  end
end
