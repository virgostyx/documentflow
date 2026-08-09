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
    expect(subject).to have_css("a[data-turbo-method='delete']", text: /[Ss]ign out/, visible: false)
  end

  it "est un header fixe en haut de la page" do
    expect(subject).to have_css("header.fixed.top-0")
  end

  it "n'affiche pas de lien vers les jobs en arrière-plan pour un utilisateur normal" do
    expect(subject).not_to have_link("Background jobs", visible: false)
  end

  it "does not show a link to the admin panel for a regular user" do
    expect(subject).not_to have_link("Admin panel", visible: false)
  end

  context "when the current user is a super admin" do
    let(:user) { build_stubbed(:user, :super_admin, email: "admin@documentflow.test") }

    it "shows a link to the background jobs dashboard" do
      expect(subject).to have_link("Background jobs", href: "/jobs", visible: false)
    end

    it "shows a link to the admin panel" do
      expect(subject).to have_link("Admin panel", href: "/admin", visible: false)
    end
  end
end
