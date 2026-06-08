# DOCUMENTFLOW - NOTE DE CONCEPT
## Système de Gestion de Flux Documentaire avec Rails 8

**Version:** 1.1  
**Date:** 9 Mars 2026 (mis à jour 6 Juin 2026)
**Framework:** Ruby on Rails 8  
**Client:** virgostyx

---

## RÉSUMÉ EXÉCUTIF

DocumentFlow est une application Rails 8 **multi-tenant** de gestion de flux documentaire avec validation multi-acteurs. Chaque tenant est une **Entité** (organisation, entreprise, administration) qui possède ses propres documents, contacts et membres. Le système gère l'enregistrement de documents, leur validation selon un workflow structuré (RED → VISA → SIGN → EXP), les notifications par email, la conversion PDF à la finalisation, et le partage temporisé.

**Hiérarchie multi-tenant :**
```
Entity (tenant)
  └── EntityUser (membres avec rôles : owner, admin, member, guest)
  └── Document  (scoped à l'entité)
        └── WorkflowStep
        └── AuditLog
        └── SharedLink
  └── Contact   (carnet d'adresses de l'entité)
```

---

## PRINCIPES DE DÉVELOPPEMENT

### Test-Driven Development (TDD)

Le développement suit strictement le cycle **Red → Green → Refactor** :

1. **Red** — Écrire un test qui échoue avant d'écrire le code de production
2. **Green** — Écrire le minimum de code pour faire passer le test
3. **Refactor** — Améliorer le code sans casser les tests

```ruby
# Exemple : Génération du numéro de référence (Red d'abord)
RSpec.describe Document, type: :model do
  describe "#generate_reference_number" do
    it "génère un numéro au format YYYY/#####" do
      doc = create(:document)
      expect(doc.reference_number).to match(/\A\d{4}\/\d{5}\z/)
    end

    it "remet le compteur à zéro chaque année" do
      travel_to Date.new(2025, 12, 31) { create(:document) }
      travel_to Date.new(2026, 1, 1) do
        doc = create(:document)
        expect(doc.reference_number).to eq("2026/00001")
      end
    end
  end
end
# → Le modèle Document.generate_reference_number n'existe pas encore.
# → On le crée pour faire passer ces tests, rien de plus.
```

**Règles TDD appliquées au projet :**
- Chaque model est spécifié avant d'être implémenté (`spec/models/`)
- Chaque service object a son propre spec (`spec/services/`)
- Les policies Pundit sont testées avec pundit-matchers (`spec/policies/`)
- Les contrôleurs sont testés via request specs, pas de controller specs
- SimpleCov enforces >80% coverage

---

### Architecture Orientée Objet (OOP)

Le code est organisé autour de **responsabilités uniques** (SRP). La logique métier n'est jamais dans les contrôleurs ni les modèles.

#### Service Layer : Organizers + Actions

Inspiré du pattern LightService utilisé dans BudgetFlow :

```
app/services/
├── application_service.rb          # Base : transaction + audit logging
├── application_action.rb           # Base : fail_with!, succeed_with!
├── documents/
│   ├── create_organizer.rb
│   ├── launch_organizer.rb
│   ├── finalize_organizer.rb
│   └── actions/
│       ├── validate_document.rb
│       ├── generate_reference.rb
│       ├── notify_next_actor.rb
│       └── convert_to_pdf.rb
└── workflow/
    ├── approve_step_organizer.rb
    ├── reject_step_organizer.rb
    └── actions/
        ├── transition_step.rb
        ├── advance_workflow.rb
        └── log_audit_event.rb
```

```ruby
# app/services/application_service.rb
class ApplicationService
  def self.call(**params)
    new(**params).call
  end

  def self.with_audit_logging(steps)
    [Shared::Actions::LogAuditEvent] + steps
  end
end

# app/services/documents/launch_organizer.rb
class Documents::LaunchOrganizer < ApplicationService
  def self.steps
    with_audit_logging([
      Documents::Actions::ValidateDocument,
      Documents::Actions::GenerateReference,
      Documents::Actions::TransitionToInProgress,
      Documents::Actions::NotifyFirstActor
    ])
  end
end

# Dans le contrôleur :
result = Documents::LaunchOrganizer.call(document: @document, current_user: current_user)
if result.success?
  redirect_to @document, notice: "Document lancé"
else
  flash[:error] = result.message
  render :show
end
```

#### Value Objects et Form Objects

```ruby
# app/value_objects/reference_number.rb
class ReferenceNumber
  FORMAT = /\A\d{4}\/\d{5}\z/

  def self.generate(year: Date.current.year)
    count = Document.where("reference_number LIKE ?", "#{year}/%").count + 1
    "#{year}/#{count.to_s.rjust(5, '0')}"
  end

  def self.valid?(value)
    value.match?(FORMAT)
  end
end

# app/forms/document_form.rb
class DocumentForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :subject, :string
  attribute :document_date, :date
  attribute :sender_id, :integer
  attribute :addressee_id, :integer

  validates :subject, presence: true, length: { maximum: 255 }
  validates :document_date, presence: true
  validates :sender_id, :addressee_id, presence: true
end
```

#### Concerns partagés

```ruby
# app/controllers/concerns/entity_scoped.rb
module EntityScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_current_entity
    before_action :authorize_entity_access!
    helper_method :current_entity
  end

  private

  def current_entity = @current_entity

  def set_current_entity
    @current_entity = Entity.find(params[:entity_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: "Entité introuvable"
  end

  def authorize_entity_access!
    entity_user = EntityUser.find_by(
      entity: @current_entity, user: current_user, status: "active"
    )
    redirect_to dashboard_path, alert: "Accès refusé" unless entity_user
  end
end

# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  include EntityScoped

  def index
    @documents = policy_scope(Document)
                   .where(entity: current_entity)
                   .includes(:sender, :addressee, :created_by)
                   .order(created_at: :desc)
                   .page(params[:page])
    @documents = @documents.search_full_text(params[:q]) if params[:q].present?
  end

  def create
    result = Documents::CreateOrganizer.call(
      entity: current_entity,
      current_user: current_user,
      params: document_params
    )
    if result.success?
      redirect_to entity_document_path(current_entity, result.document)
    else
      flash[:error] = result.message
      render :new
    end
  end
end

# app/controllers/concerns/workflow_actions.rb
module WorkflowActions
  def approve
    handle_workflow_action(
      organizer: Workflow::ApproveStepOrganizer,
      resource: :workflow_step,
      success_message: "Étape approuvée"
    )
  end

  private

  def handle_workflow_action(organizer:, resource:, success_message:)
    result = organizer.call(
      step: instance_variable_get("@#{resource}"),
      current_user: current_user
    )
    if result.success?
      redirect_back fallback_location: root_path, notice: success_message
    else
      redirect_back fallback_location: root_path, alert: result.message
    end
  end
end
```

---

## LANDING PAGE

### Structure (inspirée de BudgetFlow)

La landing page suit la même structure et look & feel que BudgetFlow :
- Couleur primaire : **Sky blue** (`primary-600` → `#0284c7`)
- Fond : `bg-white` (landing) / `bg-gray-50` (app)
- Typographie : extrabold pour les titres, gray-600 pour le corps
- Layout : header fixe `h-16` avec backdrop-blur, sidebar pour l'app

```
app/views/pages/home.html.erb
app/views/layouts/pages.html.erb
app/controllers/pages_controller.rb
app/components/auth/feature_card_component.rb
```

### Sections de la landing page

```
1. Navigation fixe
   └── Logo DocumentFlow + liens (Fonctionnalités, Workflow, Se connecter, S'inscrire)

2. Hero
   └── "Gérez vos flux documentaires avec rigueur et traçabilité"
   └── CTA : [Démarrer] + [Voir une démo]
   └── Trust badges (organisations utilisatrices)

3. Fonctionnalités (grille 3 colonnes)
   ├── Workflow structuré (RED → VISA → SIGN → EXP)
   ├── Validation multi-acteurs
   ├── Audit trail complet
   ├── Conversion PDF automatique
   ├── Partage temporisé (SharedLink)
   └── Recherche full-text

4. Comment ça marche (4 étapes numérotées)
   1. Créer un document
   2. Définir le circuit de validation
   3. Les acteurs approuvent ou rejettent
   4. Finalisation et archivage PDF

5. CTA (fond `bg-primary-600`)
   └── "Prêt à digitaliser vos flux documentaires ?"

6. Footer (fond gray-900)
```

### Routes

```ruby
# config/routes.rb
root "pages#home"    # Landing publique

# Devise
devise_for :users

# Application (authentifiée)
resources :entities do
  # Membres de l'entité
  resources :entity_users, only: [:index, :create, :update, :destroy]

  # Contacts (carnet d'adresses de l'entité)
  resources :contacts

  # Documents (ressource principale)
  resources :documents do
    resources :workflow_steps, only: [] do
      member do
        post :approve
        post :reject
      end
    end
    resources :shared_links, only: [:create, :destroy]
    member do
      post :launch    # draft → in_progress
      post :cancel    # → cancelled
    end
    collection do
      get :search
    end
  end
end

# Accès public à un document partagé (sans auth)
get "share/:token", to: "shared_links#show", as: :shared_document

# Dashboard global (liste des entités de l'utilisateur)
get "dashboard", to: "dashboard#index"
```

**URLs résultantes :**
```
/entities/:entity_id/documents
/entities/:entity_id/documents/:id
/entities/:entity_id/documents/:id/launch
/entities/:entity_id/documents/:document_id/workflow_steps/:id/approve
/share/:token
```

---

## STACK TECHNIQUE

### Backend
- **Framework:** Ruby on Rails 8.0
- **Ruby:** 3.2+ 
- **Base de données:** PostgreSQL 15+
- **Jobs:** Solid Queue (intégré Rails 8, sans Redis)
- **Cache:** Solid Cache (intégré Rails 8)
- **File Storage:** Active Storage
- **PDF:** Prawn, Libreoffice (conversion)

### Frontend
- **Turbo:** Navigation SPA sans JavaScript
- **Stimulus:** Contrôleurs JavaScript légers
- **ViewComponent:** Composants réutilisables — toutes les pages sont construites avec des composants
- **TailwindCSS:** Framework CSS utility-first — design tokens CSS (`primary`, `success`, `warning`, `danger`, `info`)
- **Importmap:** Gestion des dépendances JS
- **floating_labels_rails:** Floating labels pour tous les formulaires (custom FormBuilder)
- **FlashMessageComponent:** Notifications toast animées avec barre de progression
- **Design System:** Cohérent avec BudgetFlow — même composants, même layout, même tokens sémantiques ; seule `--primary` diffère (sky blue vs indigo)

### Production
- **Serveur:** Puma (intégré Rails)
- **Reverse Proxy:** Nginx
- **Déploiement:** Kamal 2
- **SSL:** Let's Encrypt
- **Monitoring:** Rails error reporting

---

## ARCHITECTURE RAILS

```
app/
├── models/                  # ActiveRecord : données + validations + associations
│   ├── entity.rb            # Tenant principal
│   ├── entity_user.rb       # Appartenance user↔entity avec rôle
│   ├── user.rb              # Devise — sans rôle global
│   ├── document.rb          # Scoped à Entity
│   ├── workflow_step.rb
│   ├── contact.rb           # Scoped à Entity
│   ├── audit_log.rb
│   ├── shared_link.rb
│   └── concerns/
├── controllers/             # HTTP uniquement : pas de logique métier
│   ├── application_controller.rb    # authenticate_user! + set_current_entity
│   ├── dashboard_controller.rb      # Vue globale (entités de l'user)
│   ├── entities_controller.rb
│   ├── entity_users_controller.rb
│   ├── contacts_controller.rb
│   ├── documents_controller.rb
│   ├── workflow_steps_controller.rb
│   ├── shared_links_controller.rb   # Accès public /share/:token
│   ├── pages_controller.rb          # Landing publique
│   └── concerns/
│       ├── entity_scoped.rb         # set_current_entity + authorize_entity_access!
│       ├── resource_loading.rb
│       └── workflow_actions.rb
├── views/                   # Templates ERB + Turbo Streams
│   ├── documents/
│   ├── workflow_steps/
│   ├── pages/
│   │   └── home.html.erb    # Landing page publique
│   └── layouts/
│       ├── application.html.erb  # App authentifiée
│       └── pages.html.erb        # Landing publique
├── components/              # ViewComponents (organisés par domaine)
│   ├── ui/                  # Composants génériques
│   │   ├── page_header_component.rb
│   │   ├── card_component.rb
│   │   ├── badge_component.rb
│   │   ├── button_component.rb
│   │   ├── empty_state_component.rb
│   │   ├── definition_list_component.rb
│   │   ├── modal_component.rb
│   │   ├── confirm_modal_component.rb
│   │   ├── breadcrumbs_component.rb
│   │   ├── filter_panel_component.rb
│   │   └── flash_message_component.rb
│   ├── documents/
│   │   ├── document_card_component.rb
│   │   ├── document_status_badge.rb
│   │   ├── metadata_component.rb
│   │   └── file_list_component.rb
│   ├── workflow/
│   │   ├── steps_component.rb
│   │   ├── step_component.rb
│   │   └── action_buttons_component.rb
│   ├── shared/
│   │   ├── header_component.rb
│   │   └── sidebar_component.rb
│   ├── auth/
│   │   ├── auth_layout_component.rb
│   │   └── feature_card_component.rb
│   └── previews/            # Previews sur /rails/view_components
│       ├── ui/
│       ├── documents/
│       └── workflow/
├── services/                # Business logic : Organizers + Actions
│   ├── application_service.rb
│   ├── application_action.rb
│   ├── entities/
│   │   ├── create_organizer.rb      # Crée entity + EntityUser owner
│   │   ├── invite_member_organizer.rb
│   │   └── actions/
│   ├── documents/
│   │   ├── create_organizer.rb
│   │   ├── launch_organizer.rb
│   │   ├── finalize_organizer.rb
│   │   └── actions/
│   ├── workflow/
│   │   ├── approve_step_organizer.rb
│   │   ├── reject_step_organizer.rb
│   │   └── actions/
│   └── shared/
│       └── actions/
│           └── log_audit_event.rb
├── value_objects/           # Objets de valeur immuables
│   ├── reference_number.rb
│   └── workflow_role.rb
├── forms/                   # Form Objects pour validations complexes
│   └── document_form.rb
├── jobs/                    # Solid Queue jobs
│   ├── notification_job.rb
│   ├── pdf_conversion_job.rb
│   └── reminder_job.rb
├── mailers/                 # Action Mailer
│   └── notification_mailer.rb
└── javascript/              # Stimulus controllers
    ├── controllers/
    │   ├── floating_label_controller.js  # Animation floating labels
    │   ├── flash_controller.js           # Toast notifications + progress bar
    │   ├── password_toggle_controller.js # Show/hide password
    │   ├── workflow_builder_controller.js # Drag-and-drop circuit
    │   ├── file_upload_controller.js     # Upload + aperçu fichiers
    │   └── navbar_controller.js          # Menu mobile landing
    └── application.js
```

---

## MODÈLE DE DONNÉES

### Architecture Multi-Tenant

Toutes les ressources sont scopées à une **Entity** (tenant). Un utilisateur peut appartenir à plusieurs entités avec des rôles différents dans chacune.

```
User ──────────── EntityUser ──────────── Entity
                  (rôle dans entity)       (tenant)
                                              │
                               ┌──────────────┼──────────────┐
                            Document       Contact        (futur)
                               │
                    ┌──────────┼──────────┐
               WorkflowStep  AuditLog  SharedLink
```

### Modèles

**Entity** (tenant)
- `name` : nom de l'organisation (unique)
- `code` : code auto-généré `ENT-XXXXXX`
- `status` : active, suspended, cancelled
- `logo` : Active Storage
- Crée automatiquement un `EntityUser` owner à la création

**EntityUser** (appartenance d'un User à une Entity)
- `role` : owner, admin, member, guest
- `status` : pending, active, suspended
- `invited_email` : pour les invitations
- `invitation_token` : token d'invitation par email
- Un User peut avoir plusieurs EntityUser dans différentes entités

**User** (Devise)
- Authentification email/password
- Pas de rôle global — les rôles sont définis par EntityUser
- Peut être `super_admin` (accès admin global)

**Document** (scoped à Entity)
- `entity` : belong_to Entity
- `reference_number` : YYYY/##### (compteur par entité, reset annuel)
- `status` : draft, in_progress, signed, finalized, cancelled
- `is_frozen` : true après finalisation
- `created_by` : User

**WorkflowStep**
- Rôles : RED, VISA, SIGN, EXP
- VISA parallèles supportés (`is_parallel`, `parallel_group`)
- Statuts : pending, approved, rejected, skipped
- `actor` : User membre de l'entité

**Contact** (scoped à Entity)
- Carnet d'adresses de l'entité
- Pour expéditeur/destinataire des documents

**DocumentFile** (Active Storage)
- 25 MB par fichier max
- 100 MB par document max
- Formats : docx, xlsx, pptx, pdf, jpg, png, gif, txt, csv, zip, rar

**AuditLog** (scoped à Entity via Document)
- Trail complet de toutes les actions

**SharedLink**
- Token UUID, expiration 15 jours
- Accès public temporaire à un document finalisé

---

## WORKFLOW RAILS

### State Machine avec AASM

```ruby
class Document < ApplicationRecord
  include AASM
  
  aasm column: :status do
    state :draft, initial: true
    state :in_progress, :signed, :finalized, :cancelled
    
    event :launch do
      transitions from: :draft, to: :in_progress
    end
    
    event :sign do
      transitions from: :in_progress, to: :signed
    end
    
    event :finalize do
      transitions from: :signed, to: :finalized, after: :freeze_document
    end
    
    event :cancel do
      transitions from: [:draft, :in_progress, :signed], to: :cancelled
    end
  end
end
```

### Service Objects

```ruby
# app/services/workflow_state_machine.rb
class WorkflowStateMachine
  def initialize(document)
    @document = document
  end
  
  def launch_workflow
    # Validation et lancement
  end
  
  def approve_step(step, message: nil)
    # Approbation et passage au suivant
  end
  
  def reject_step(step, reason:)
    # Rejet et retour au précédent
  end
end
```

---

## SOLID QUEUE

Rails 8 inclut **Solid Queue** - système de jobs sans Redis.

### Configuration

```ruby
# config/queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 5
      polling_interval: 0.1
```

### Jobs

```ruby
# app/jobs/notification_job.rb
class NotificationJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(user_id, notification_type, document_id)
    user = User.find(user_id)
    document = Document.find(document_id)
    NotificationMailer.send_notification(user, notification_type, document).deliver_now
  end
end
```

### Jobs Récurrents

```ruby
# config/recurring.yml
daily_reminders:
  class: DailyRemindersJob
  schedule: "every day at 9am"
  
cleanup_expired_links:
  class: CleanupExpiredLinksJob
  schedule: "every day at 2am"
```

---

## DESIGN SYSTEM : COHÉRENCE AVEC BUDGETFLOW

### Principe fondamental

DocumentFlow et BudgetFlow partagent le **même design system**. Un utilisateur qui passe de l'un à l'autre retrouve immédiatement ses repères : même layout, même typographie, mêmes composants, mêmes patterns d'interaction. La seule différence visible est la couleur primaire.

| Élément | BudgetFlow | DocumentFlow |
|---------|------------|--------------|
| Couleur primaire | Indigo (`#4f46e5`) | Sky blue (`#0284c7`) |
| Layout | Header fixe h-16 + `bg-gray-50` | Identique |
| Typographie | Inter var, extrabold headings | Identique |
| Composants | `Ui::*`, `Shared::*` | API identique |
| Formulaires | Floating labels | Identique |
| Flash messages | Toast + progress bar | Identique |
| Design tokens | `--bf-primary-*` → indigo | `--df-primary-*` → sky |

### Design Tokens CSS

DocumentFlow adopte la **même architecture de tokens** que BudgetFlow : CSS custom properties mappées dans Tailwind comme couleurs sémantiques. Les composants utilisent `bg-primary-600`, jamais `bg-sky-600` directement — ce qui les rend portables entre les deux apps.

```css
/* app/assets/stylesheets/config/design_tokens.css */
:root {
  /* Primary — Sky Blue (différence vs BudgetFlow qui utilise Indigo) */
  --df-primary-50:  #f0f9ff;
  --df-primary-100: #e0f2fe;
  --df-primary-200: #bae6fd;
  --df-primary-300: #7dd3fc;
  --df-primary-400: #38bdf8;
  --df-primary-500: #0ea5e9;
  --df-primary-600: #0284c7;
  --df-primary-700: #0369a1;
  --df-primary-800: #075985;
  --df-primary-900: #0c4a6e;

  /* Gray, Success, Warning, Danger, Info — identiques à BudgetFlow */
  --df-gray-50: #f9fafb;  --df-gray-100: #f3f4f6;  --df-gray-200: #e5e7eb;
  --df-gray-300: #d1d5db; --df-gray-400: #9ca3af;  --df-gray-500: #6b7280;
  --df-gray-600: #4b5563; --df-gray-700: #374151;  --df-gray-800: #1f2937;
  --df-gray-900: #111827;

  --df-success-600: #16a34a; --df-success-100: #dcfce7;
  --df-warning-600: #ca8a04; --df-warning-100: #fef3c7;
  --df-danger-600:  #dc2626; --df-danger-100:  #fee2e2;
  --df-info-600:    #2563eb; --df-info-100:    #dbeafe;

  /* Spacing, Typography, Borders, Shadows — identiques à BudgetFlow */
  --df-spacing-xs: 0.25rem; --df-spacing-sm: 0.5rem;  --df-spacing-md: 1rem;
  --df-spacing-lg: 1.5rem;  --df-spacing-xl: 2rem;    --df-spacing-2xl: 3rem;
}
```

```js
// config/tailwind.config.js
module.exports = {
  theme: {
    extend: {
      fontFamily: { sans: ['Inter var', ...defaultTheme.fontFamily.sans] },
      colors: {
        primary: {
          50: 'var(--df-primary-50)',   100: 'var(--df-primary-100)',
          600: 'var(--df-primary-600)', 700: 'var(--df-primary-700)',
        },
        // success, warning, danger, info — même structure que BudgetFlow
        success: { 100: 'var(--df-success-100)', 600: 'var(--df-success-600)' },
        warning: { 100: 'var(--df-warning-100)', 600: 'var(--df-warning-600)' },
        danger:  { 100: 'var(--df-danger-100)',  600: 'var(--df-danger-600)'  },
        info:    { 100: 'var(--df-info-100)',     600: 'var(--df-info-600)'    },
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}
```

### Éléments de layout identiques à BudgetFlow

```
Header fixe
  bg-white border-b border-gray-200 fixed top-0 left-0 right-0 z-50 h-16
  └── Logo (DocumentFlow) + navigation principale + user dropdown

Corps de page
  bg-gray-50 antialiased
  main class="pt-16"      ← compense la hauteur du header fixe

Page intérieure
  max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8

Flash messages
  fixed top-20 left-1/2 -translate-x-1/2 z-[100] max-w-md
```

### Composants partagés par API (même interface, sky blue au lieu d'indigo)

```ruby
# Identique à BudgetFlow — seule la couleur du token `primary` change
render Ui::ButtonComponent.new(variant: :primary)   # → sky-600 au lieu d'indigo-600
render Ui::ButtonComponent.new(variant: :danger)    # → identique (rouge)
render Ui::BadgeComponent.new(color: :primary)      # → sky-100 text-sky
render Ui::PageHeaderComponent.new(title: "...", back_path: ...)
render Ui::CardComponent.new
render Ui::EmptyStateComponent.new(title: "...", icon: :document)
render Ui::DefinitionListComponent.new do |dl| ... end
render Shared::HeaderComponent.new(current_entity: @entity, current_user: current_user)
```

### Ce qui est intentionnellement identique

- Navigation header : même structure, même hauteur, même user dropdown
- Fil d'Ariane : `Ui::BreadcrumbsComponent` avec chevron gris
- En-têtes de page : `Ui::PageHeaderComponent` avec lien retour + `text-3xl font-bold text-gray-900`
- Cartes : `Ui::CardComponent` — `bg-white rounded-lg shadow-md border border-gray-200 p-6`
- États vides : `Ui::EmptyStateComponent` — fond gris pointillé, icône gris-400
- Boutons : `Ui::ButtonComponent` — `rounded-md font-medium transition-colors focus:ring-2`
- Badges : `Ui::BadgeComponent` — `rounded-full font-medium`
- Formulaires : floating labels, bordure grise, focus ring `primary-500`
- Flash messages : toast slide-down, icône colorée, progress bar, pause au survol

---

## FORMULAIRES : FLOATING LABELS

### Gem `floating_labels_rails`

Tous les formulaires utilisent des **floating labels** via la gem `floating_labels_rails`, exactement comme dans BudgetFlow. Le `FormBuilder` personnalisé gère automatiquement les erreurs de validation (bordure rouge, label rouge, message d'erreur).

```ruby
# config/application.rb
config.action_view.default_form_builder = FloatingLabelsRails::FormBuilder
```

### Méthodes disponibles

```erb
<%# app/views/documents/_form.html.erb %>
<%= form_with model: [@entity, @document] do |f| %>
  <%= f.floating_text_field   :subject,       required: true %>
  <%= f.floating_date_field   :document_date, required: true %>
  <%= f.floating_collection_select :sender_id,
        @contacts, :id, :full_name,
        { include_blank: "Sélectionner l'expéditeur..." },
        { required: true } %>
  <%= f.floating_collection_select :addressee_id,
        @contacts, :id, :full_name,
        { include_blank: "Sélectionner le destinataire..." } %>
  <%= f.floating_text_area :notes, rows: 3 %>
<% end %>

<%# app/views/devise/sessions/new.html.erb %>
<%= form_for resource, as: resource_name, url: session_path(resource_name) do |f| %>
  <%= f.floating_email_field    :email,    required: true %>
  <%= f.floating_password_field :password, required: true %>
<% end %>
```

### Comportement

- Le label flotte vers le haut au focus ou quand le champ a une valeur
- Erreur de validation → bordure rouge + label rouge + message sous le champ
- Contrôleur Stimulus `floating_label_controller.js` gère l'animation
- Password field inclut un bouton toggle show/hide

### Stimulus Controllers pour les formulaires

```
app/javascript/controllers/
├── floating_label_controller.js   # Animation des labels (focus/blur/checkValue)
├── password_toggle_controller.js  # Afficher/masquer le mot de passe
└── file_upload_controller.js      # Aperçu avant upload, drag-and-drop
```

---

## FLASH MESSAGES

### `FlashMessageComponent` + Stimulus `flash_controller.js`

Les notifications sont identiques à BudgetFlow : toast animé avec barre de progression et pause au survol.

```ruby
# app/components/flash_message_component.rb
class FlashMessageComponent < ViewComponent::Base
  CONFIGS = {
    notice:  { bg: "bg-green-50",  border: "border-green-200",  text: "text-green-800",
               icon_bg: "bg-green-100",  icon_color: "text-green-600",  progress: "bg-green-400",
               icon_path: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" },
    alert:   { bg: "bg-yellow-50", border: "border-yellow-200", text: "text-yellow-800",
               icon_bg: "bg-yellow-100", icon_color: "text-yellow-600", progress: "bg-yellow-400",
               icon_path: "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948..." },
    error:   { bg: "bg-red-50",    border: "border-red-200",    text: "text-red-800",
               icon_bg: "bg-red-100",    icon_color: "text-red-600",    progress: "bg-red-400",
               icon_path: "M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0..." },
    info:    { bg: "bg-blue-50",   border: "border-blue-200",   text: "text-blue-800",
               icon_bg: "bg-blue-100",   icon_color: "text-blue-600",   progress: "bg-blue-400",
               icon_path: "M11.25 11.25l.041-.02a.75.75 0 011.063.852..." }
  }.freeze

  def initialize(type:, message:, duration: 5000)
    @type     = type.to_sym
    @message  = message
    @duration = duration
    @config   = CONFIGS[@type] || CONFIGS[:info]
  end
end
```

```erb
<%# app/views/shared/_flash.html.erb — inclus dans application.html.erb %>
<div id="flash-messages" class="fixed top-20 left-1/2 -translate-x-1/2 z-[100] w-full max-w-md px-4 space-y-2">
  <% flash.each do |type, message| %>
    <%= render FlashMessageComponent.new(type: type, message: message) %>
  <% end %>
</div>
```

**Comportement :**
- Apparaît avec animation slide-down + fade-in
- Barre de progression qui se vide en 5 secondes
- Pause automatique au survol (mouseenter/mouseleave)
- Bouton ✕ pour fermeture manuelle
- 4 variantes : notice (vert), alert (jaune), error (rouge), info (bleu)

---

## TURBO + STIMULUS

### Turbo Frames

```erb
<!-- app/views/documents/index.html.erb -->
<%= turbo_frame_tag "documents" do %>
  <%= render @documents %>
  <%= paginate @documents %>
<% end %>

<!-- Recherche live -->
<%= form_with url: documents_path, method: :get, 
    data: { turbo_frame: "documents", turbo_action: "advance" } do |f| %>
  <%= f.search_field :q, placeholder: "Rechercher...", 
      data: { action: "input->debounce#search" } %>
<% end %>
```

### Stimulus Controllers

```javascript
// app/javascript/controllers/workflow_builder_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["steps", "template"]
  
  connect() {
    this.sortable = Sortable.create(this.stepsTarget, {
      animation: 150,
      handle: ".drag-handle",
      onEnd: this.updateOrder.bind(this)
    })
  }
  
  addStep() {
    const content = this.templateTarget.innerHTML
    this.stepsTarget.insertAdjacentHTML('beforeend', content)
  }
  
  updateOrder(event) {
    const steps = Array.from(this.stepsTarget.children)
    steps.forEach((step, index) => {
      step.querySelector('[name*="[order]"]').value = index + 1
    })
  }
}
```

---

## VIEW COMPONENTS

### Principe : toutes les pages sont construites avec des ViewComponents

Les vues ERB ne contiennent pas de HTML brut — elles assemblent des composants. Cette approche garantit cohérence visuelle, testabilité unitaire, et réutilisabilité à travers l'application.

```erb
<%# app/views/documents/show.html.erb — vue = assemblage de composants %>
<%= render Ui::PageHeaderComponent.new(
  title: @document.reference_number,
  description: @document.subject,
  back_path: documents_path,
  back_text: "Tous les documents"
) %>

<%= render Ui::CardComponent.new do |card| %>
  <% card.with_header { render Documents::MetadataComponent.new(document: @document) } %>
  <%= render Ui::DefinitionListComponent.new do |dl| %>
    <% dl.with_item(term: "Statut", badge: @document.status_badge) { @document.status_label } %>
    <% dl.with_item(term: "Date du document") { l(@document.document_date) } %>
    <% dl.with_item(term: "Expéditeur") { @document.sender.full_name } %>
  <% end %>
<% end %>

<%= render Workflow::StepsComponent.new(document: @document, current_user: current_user) %>
<%= render Workflow::ActionButtonsComponent.new(document: @document, current_user: current_user) %>
```

---

### Catalogue des composants

```
app/components/
├── shared/
│   ├── header_component.rb            # Header fixe de l'app (navigation principale)
│   └── sidebar_component.rb           # Sidebar contextuelle (si nécessaire)
│
├── ui/                                # Composants génériques réutilisables
│   ├── page_header_component.rb       # Titre de page + lien retour + description
│   ├── card_component.rb              # Carte blanche avec header/footer slots
│   ├── badge_component.rb             # Badges colorés (statuts, rôles)
│   ├── button_component.rb            # Bouton avec variants (primary, secondary, danger)
│   ├── button_group_component.rb      # Groupe de boutons
│   ├── breadcrumbs_component.rb       # Fil d'Ariane
│   ├── empty_state_component.rb       # État vide (liste sans résultats)
│   ├── definition_list_component.rb   # dl/dt/dd avec styling cohérent
│   ├── modal_component.rb             # Modal générique
│   ├── confirm_modal_component.rb     # Modal de confirmation d'action
│   ├── filter_panel_component.rb      # Panneau de filtres
│   ├── flash_message_component.rb     # Messages flash
│   └── tooltip_component.rb           # Info-bulles
│
├── entities/
│   ├── entity_card_component.rb       # Carte d'entité dans le dashboard
│   └── member_row_component.rb        # Ligne membre avec rôle + actions
├── auth/
│   ├── auth_layout_component.rb       # Layout des pages d'authentification
│   └── feature_card_component.rb      # Carte "fonctionnalité" (landing page)
│
├── documents/
│   ├── document_card_component.rb     # Carte de document dans une liste
│   ├── document_status_badge.rb       # Badge de statut (draft, in_progress...)
│   ├── metadata_component.rb          # Bloc expéditeur/destinataire/date
│   └── file_list_component.rb         # Liste des fichiers attachés
│
└── workflow/
    ├── steps_component.rb             # Timeline visuelle du circuit complet
    ├── step_component.rb              # Étape individuelle (rôle, acteur, statut)
    └── action_buttons_component.rb    # Boutons d'action selon policy + état AASM
```

---

### Exemples de composants clés

#### `Ui::PageHeaderComponent`

```ruby
# app/components/ui/page_header_component.rb
module Ui
  class PageHeaderComponent < ViewComponent::Base
    attr_reader :title, :description, :back_path, :back_text

    def initialize(title:, description: nil, back_path: nil, back_text: "Retour")
      @title       = title
      @description = description
      @back_path   = back_path
      @back_text   = back_text
    end
  end
end
```

#### `Ui::BadgeComponent`

```ruby
# app/components/ui/badge_component.rb
module Ui
  class BadgeComponent < ViewComponent::Base
    COLORS = {
      gray:    "bg-gray-100 text-gray-700",
      blue:    "bg-blue-100 text-blue-700",
      green:   "bg-green-100 text-green-700",
      yellow:  "bg-yellow-100 text-yellow-700",
      red:     "bg-red-100 text-red-700",
      primary: "bg-primary-100 text-primary-700"
    }.freeze

    def initialize(color: :gray, size: :md, **html_options)
      @color       = color
      @size        = size
      @html_options = html_options
    end

    private

    def badge_classes
      "inline-flex items-center font-medium rounded-full px-2.5 py-0.5 text-xs #{COLORS[@color]}"
    end
  end
end
```

#### `Documents::DocumentCardComponent`

```ruby
# app/components/documents/document_card_component.rb
module Documents
  class DocumentCardComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document     = document
      @current_user = current_user
    end

    private

    def status_color
      case @document.status
      when "draft"        then :gray
      when "in_progress"  then :blue
      when "signed"       then :sky
      when "finalized"    then :green
      when "cancelled"    then :red
      end
    end
  end
end
```

#### `Workflow::ActionButtonsComponent`

Détecte automatiquement les actions disponibles selon la policy Pundit et les guards AASM :

```ruby
# app/components/workflow/action_buttons_component.rb
module Workflow
  class ActionButtonsComponent < ViewComponent::Base
    def initialize(document:, current_user:)
      @document     = document
      @current_user = current_user
      @policy       = Pundit.policy!(current_user, document)
    end

    def show_approve?
      @policy.approve? && @document.current_step&.actor == @current_user
    end

    def show_reject?
      @policy.reject? &&
        @document.current_step&.actor == @current_user &&
        @document.current_step&.role != "RED"
    end

    def show_cancel?
      @policy.cancel?
    end
  end
end
```

---

### TDD des composants

Chaque composant a sa spec, écrite avant l'implémentation :

```ruby
# spec/components/documents/document_card_component_spec.rb
RSpec.describe Documents::DocumentCardComponent, type: :component do
  let(:user)     { build_stubbed(:user) }
  let(:document) { build_stubbed(:document, status: "draft", subject: "Contrat fournisseur") }

  subject { render_inline(described_class.new(document: document, current_user: user)) }

  it "affiche la référence du document" do
    expect(subject).to have_text(document.reference_number)
  end

  it "affiche le badge de statut" do
    expect(subject).to have_css(".badge", text: "Brouillon")
  end

  context "quand le document est finalisé" do
    let(:document) { build_stubbed(:document, status: "finalized") }

    it "affiche un badge vert" do
      expect(subject).to have_css(".badge.bg-green-100")
    end
  end
end

# spec/components/workflow/action_buttons_component_spec.rb
RSpec.describe Workflow::ActionButtonsComponent, type: :component do
  let(:actor)    { create(:user) }
  let(:document) { create(:document, :with_workflow, :in_progress) }

  before { document.workflow_steps.first.update!(actor: actor, status: "pending") }

  it "affiche le bouton approuver pour l'acteur courant" do
    rendered = render_inline(described_class.new(document: document, current_user: actor))
    expect(rendered).to have_button("Approuver")
  end

  it "ne montre pas le bouton rejeter pour un acteur RED" do
    red_step = document.workflow_steps.find_by(role: "RED")
    red_step.update!(actor: actor)
    rendered = render_inline(described_class.new(document: document, current_user: actor))
    expect(rendered).not_to have_button("Rejeter")
  end
end
```

---

### Previews (développement)

Chaque composant a une preview accessible sur `/rails/view_components` :

```ruby
# spec/components/previews/documents/document_card_component_preview.rb
class Documents::DocumentCardComponentPreview < ViewComponent::Preview
  def default
    document = Document.first || FactoryBot.build(:document)
    user = User.first || FactoryBot.build(:user)
    render(Documents::DocumentCardComponent.new(document: document, current_user: user))
  end

  def finalized
    document = FactoryBot.build(:document, :finalized)
    render(Documents::DocumentCardComponent.new(document: document, current_user: FactoryBot.build(:user)))
  end
end
```

---

## ACTION MAILER

### Configuration

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.sendgrid.net',
  port: 587,
  authentication: :plain,
  user_name: 'apikey',
  password: Rails.application.credentials.dig(:sendgrid, :api_key),
  enable_starttls_auto: true
}
```

### Mailer

```ruby
# app/mailers/notification_mailer.rb
class NotificationMailer < ApplicationMailer
  def action_required(user, document)
    @user = user
    @document = document
    @url = document_url(document)
    
    mail(
      to: user.email,
      subject: "Action requise : #{document.reference_number}"
    )
  end
  
  def rejection_alert(user, document, reason)
    @user = user
    @document = document
    @reason = reason
    
    mail(
      to: user.email,
      subject: "Document rejeté : #{document.reference_number}"
    )
  end
end
```

---

## ACTIVE STORAGE

### Configuration

```ruby
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

production:
  service: Disk
  root: <%= Rails.root.join("storage") %>
  # Ou S3 si préféré
```

### Validation

```ruby
class Document < ApplicationRecord
  has_many_attached :files
  
  validates :files, 
    content_type: {
      in: %w[
        application/pdf
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        image/jpeg
        image/png
      ],
      message: "doit être PDF, DOCX, JPG ou PNG"
    },
    size: { 
      less_than: 25.megabytes, 
      message: "doit faire moins de 25MB" 
    }
  
  validate :total_size_limit
  
  private
  
  def total_size_limit
    return unless files.attached?
    
    total = files.sum { |file| file.byte_size }
    if total > 100.megabytes
      errors.add(:files, "la taille totale dépasse 100MB")
    end
  end
end
```

---

## CONVERSION PDF

### Service de Conversion

```ruby
# app/services/pdf_converter.rb
class PdfConverter
  def self.convert(file_path)
    case File.extname(file_path).downcase
    when '.docx', '.xlsx', '.pptx'
      convert_with_libreoffice(file_path)
    when '.txt'
      convert_with_prawn(file_path)
    when '.jpg', '.jpeg', '.png'
      convert_image_to_pdf(file_path)
    when '.pdf'
      file_path # Déjà PDF
    else
      raise "Format non supporté"
    end
  end
  
  private
  
  def self.convert_with_libreoffice(input)
    output_dir = File.dirname(input)
    system("soffice --headless --convert-to pdf --outdir #{output_dir} #{input}")
    input.sub(/\.\w+$/, '.pdf')
  end
  
  def self.convert_with_prawn(input)
    output = input.sub('.txt', '.pdf')
    Prawn::Document.generate(output) do |pdf|
      pdf.text File.read(input)
    end
    output
  end
  
  def self.convert_image_to_pdf(input)
    output = input.sub(/\.(jpg|jpeg|png)$/i, '.pdf')
    Prawn::Document.generate(output) do |pdf|
      pdf.image input, fit: [500, 700]
    end
    output
  end
end
```

### Job de Conversion

```ruby
# app/jobs/pdf_conversion_job.rb
class PdfConversionJob < ApplicationJob
  queue_as :default
  
  def perform(document_id)
    document = Document.find(document_id)
    
    document.files.each do |file|
      next if file.content_type == 'application/pdf'
      
      file.open do |temp_file|
        pdf_path = PdfConverter.convert(temp_file.path)
        
        document.files.attach(
          io: File.open(pdf_path),
          filename: "#{file.filename.base}.pdf",
          content_type: 'application/pdf'
        )
        
        File.delete(pdf_path) if File.exist?(pdf_path)
      end
    end
  end
end
```

---

## RECHERCHE FULL-TEXT

### Configuration PostgreSQL

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  include PgSearch::Model
  
  pg_search_scope :search_full_text,
    against: [:reference_number, :subject],
    associated_against: {
      sender: [:first_name, :last_name, :email],
      addressee: [:first_name, :last_name, :email]
    },
    using: {
      tsearch: {
        prefix: true,
        dictionary: "french"
      },
      trigram: {
        threshold: 0.3
      }
    }
end
```

### Contrôleur

```ruby
# app/controllers/documents_controller.rb
def index
  @documents = Document.accessible_by(current_user)
  
  if params[:q].present?
    @documents = @documents.search_full_text(params[:q])
  end
  
  @documents = @documents.includes(:sender, :addressee, :created_by)
                         .order(created_at: :desc)
                         .page(params[:page])
end
```

---

## AUTORISATION

### Pundit avec rôles Entity

Les rôles sont définis par `EntityUser`, pas sur `User` directement. L'`ApplicationPolicy` expose des helpers `entity_owner?`, `entity_admin?`, `entity_member?`, `entity_guest?` qui résolvent le rôle du `user` dans l'entité du `record`.

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user   = user
    @record = record
  end

  protected

  def entity_user
    entity = entity_from_record
    return nil unless entity
    EntityUser.find_by(entity: entity, user: user, status: "active")
  end

  def entity_from_record
    case record
    when Document  then record.entity
    when Contact   then record.entity
    when Entity    then record
    end
  end

  def entity_owner?   = entity_user&.owner?   || false
  def entity_admin?   = entity_user&.admin?   || false
  def entity_member?  = entity_user&.member?  || false
  def entity_guest?   = entity_user&.guest?   || false

  def entity_staff?
    entity_owner? || entity_admin? || entity_member?
  end
end

# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  def index?
    entity_staff? || entity_guest?
  end

  def create?
    entity_staff?
  end

  def update?
    return false if record.is_frozen?

    if record.draft?
      record.created_by == user || entity_admin? || entity_owner?
    elsif record.in_progress?
      record.current_step&.actor == user
    else
      false
    end
  end

  def destroy?
    entity_owner? || entity_admin?
  end

  def cancel?
    return false if record.finalized?
    record.created_by == user || entity_admin? || entity_owner?
  end

  def approve?
    record.current_step&.actor == user
  end

  def reject?
    record.current_step&.actor == user &&
      record.current_step&.role != "RED"
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(entity: accessible_entities)
    end

    private

    def accessible_entities
      EntityUser.where(user: user, status: "active").select(:entity_id)
    end
  end
end

# app/policies/entity_policy.rb
class EntityPolicy < ApplicationPolicy
  def show?    = entity_owner? || entity_admin? || entity_member? || entity_guest?
  def update?  = entity_owner? || entity_admin?
  def destroy? = entity_owner?

  def manage_members? = entity_owner? || entity_admin?
end
```

---

## TESTS (TDD)

### Cycle Red → Green → Refactor

Chaque feature commence par des specs. On écrit le test, on le voit échouer, puis on implémente.

### Structure des specs

```
spec/
├── models/             # Validations, associations, state machine
├── services/           # Organizers et Actions unitairement
├── policies/           # Pundit avec pundit-matchers
├── requests/           # Contrôleurs via HTTP (pas de controller specs)
├── components/         # ViewComponents (render_inline)
│   ├── ui/
│   ├── documents/
│   └── workflow/
├── value_objects/      # ReferenceNumber, WorkflowRole
├── forms/              # Form objects
├── factories/          # FactoryBot
└── support/            # Helpers partagés
```

### Exemples de specs TDD

```ruby
# spec/value_objects/reference_number_spec.rb
RSpec.describe ReferenceNumber do
  describe ".generate" do
    it "génère le format YYYY/#####" do
      expect(described_class.generate(year: 2026)).to match(/\A2026\/\d{5}\z/)
    end

    it "remet le compteur à 1 en début d'année" do
      travel_to Date.new(2025, 12, 31) { create(:document) }
      travel_to Date.new(2026, 1, 1) do
        expect(described_class.generate).to eq("2026/00001")
      end
    end
  end
end

# spec/services/documents/launch_organizer_spec.rb
RSpec.describe Documents::LaunchOrganizer do
  let(:user)     { create(:user) }
  let(:document) { create(:document, :with_workflow, created_by: user) }

  describe ".call" do
    context "quand le document est en draft" do
      it "passe le document en in_progress" do
        expect {
          described_class.call(document: document, current_user: user)
        }.to change { document.reload.status }.from("draft").to("in_progress")
      end

      it "notifie le premier acteur" do
        expect(NotificationJob).to receive(:perform_later)
        described_class.call(document: document, current_user: user)
      end

      it "enregistre un audit log" do
        expect {
          described_class.call(document: document, current_user: user)
        }.to change(AuditLog, :count).by(1)
      end
    end

    context "quand le document n'a pas de circuit" do
      let(:document) { create(:document) }

      it "retourne une erreur" do
        result = described_class.call(document: document, current_user: user)
        expect(result).not_to be_success
        expect(result.message).to include("circuit de validation")
      end
    end
  end
end

# spec/policies/document_policy_spec.rb
RSpec.describe DocumentPolicy, type: :policy do
  let(:admin)   { create(:user, :admin) }
  let(:user)    { create(:user) }
  let(:document) { create(:document, created_by: user) }

  subject { described_class }

  permissions :update? do
    it { is_expected.to permit(user, document)  }
    it { is_expected.not_to permit(admin, create(:document, :finalized)) }
  end

  permissions :cancel? do
    it { is_expected.to permit(user, document)  }
    it { is_expected.not_to permit(create(:user), document) }
  end
end
```

### Factories avec séquences

```ruby
# spec/factories/documents.rb
FactoryBot.define do
  factory :document do
    sequence(:reference_number) { |n| "2026/#{n.to_s.rjust(5, '0')}" }
    document_date { Date.today }
    subject       { Faker::Lorem.sentence }
    status        { "draft" }
    is_frozen     { false }
    association :sender,     factory: :contact
    association :addressee,  factory: :contact
    association :created_by, factory: :user

    trait :with_workflow do
      after(:create) do |document|
        create(:workflow_step, :red,  document: document, order: 1)
        create(:workflow_step, :visa, document: document, order: 2)
        create(:workflow_step, :sign, document: document, order: 3)
        create(:workflow_step, :exp,  document: document, order: 4)
      end
    end

    trait :finalized do
      status    { "finalized" }
      is_frozen { true }
      finalized_at { Time.current }
    end
  end
end
```

---

## DÉPLOIEMENT AVEC KAMAL

### Configuration

```yaml
# config/deploy.yml
service: documentflow

image: your-username/documentflow

servers:
  web:
    hosts:
      - your-vps-ip
    labels:
      traefik.http.routers.documentflow.rule: Host(`documentflow.yourdomain.com`)
    options:
      network: "private"
  
  jobs:
    hosts:
      - your-vps-ip
    cmd: bundle exec rake solid_queue:start
    options:
      network: "private"

registry:
  username: your-dockerhub-username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
  clear:
    RAILS_ENV: production
    DATABASE_URL: postgres://documentflow:password@postgres/documentflow_production

accessories:
  postgres:
    image: postgres:17
    host: your-vps-ip
    port: 5432
    env:
      secret:
        - POSTGRES_PASSWORD
      clear:
        POSTGRES_USER: documentflow
        POSTGRES_DB: documentflow_production
    directories:
      - data:/var/lib/postgresql/data

traefik:
  options:
    publish:
      - 443:443
    volume:
      - /letsencrypt:/letsencrypt
  args:
    certificatesResolvers.letsencrypt.acme.email: "your-email@domain.com"

volumes:
  - "storage:/rails/storage"
```

### Déploiement

```bash
# Premier déploiement
kamal setup

# Déploiements suivants
kamal deploy

# Rollback si nécessaire
kamal rollback
```

---

## AVANTAGES DE RAILS 8

### 1. Solid Queue (Sans Redis)
- ✅ Jobs persistés en PostgreSQL
- ✅ Pas de dépendance Redis
- ✅ Transactions atomiques
- ✅ Interface web intégrée

### 2. Convention over Configuration
- ✅ Structure claire et cohérente
- ✅ Moins de décisions à prendre
- ✅ Productivité accrue

### 3. Active Record
- ✅ ORM puissant et élégant
- ✅ Migrations versionnées
- ✅ Validations intégrées
- ✅ Callbacks

### 4. Turbo + Stimulus
- ✅ SPA sans complexité JavaScript
- ✅ Progressive enhancement
- ✅ HTML over the wire
- ✅ Contrôleurs JS légers et ciblés

### 5. ViewComponent
- ✅ Composants réutilisables
- ✅ Testables unitairement
- ✅ Encapsulation
- ✅ Performance

---

## STRUCTURE DU PROJET

```
documentflow/
├── app/
│   ├── models/
│   ├── controllers/
│   ├── views/
│   ├── components/
│   ├── services/
│   ├── jobs/
│   ├── mailers/
│   └── javascript/
├── config/
│   ├── routes.rb
│   ├── database.yml
│   ├── queue.yml
│   ├── recurring.yml
│   └── deploy.yml
├── db/
│   ├── migrate/
│   └── seeds.rb
├── spec/
│   ├── models/
│   ├── requests/
│   ├── components/
│   └── services/
├── Gemfile
├── Dockerfile
└── README.md
```

---

## PROCHAINES ÉTAPES

### Phase 1 — Setup & Landing Page (1 jour)
- [ ] Setup Rails 8, PostgreSQL, gems
- [ ] Landing page (pages#home) — look & feel BudgetFlow (sky blue)
- [ ] Layout `pages.html.erb` (public) + `application.html.erb` (app)
- [ ] Auth Devise (login/signup depuis la landing)

### Phase 2 — Models en TDD (2-3 jours)
- [ ] Spec + migration `Entity` (name, code, status, logo) → implémenter
- [ ] Spec + migration `EntityUser` (role, status, invitation) → implémenter
- [ ] Spec `ReferenceNumber` value object (compteur par entité) → implémenter
- [ ] Spec model `Document` (scoped entity, validations, state machine) → implémenter
- [ ] Spec model `WorkflowStep` → implémenter
- [ ] Spec model `Contact`, `AuditLog`, `SharedLink` (scoped entity)
- [ ] Spec policy `EntityPolicy` → implémenter
- [ ] Spec policy `DocumentPolicy` (rôles entity) → implémenter

### Phase 3 — Service Layer en TDD (1 semaine)
- [x] Spec `Entities::CreateOrganizer` (entity + owner EntityUser) → implémenter
- [x] Spec `Entities::InviteMemberOrganizer` (invitation email) → implémenter
- [x] Spec `Documents::CreateOrganizer` (scoped entity) → implémenter
- [x] Spec `Documents::LaunchOrganizer` → implémenter
- [x] Spec `Workflow::ApproveStepOrganizer` → implémenter
- [x] Spec `Workflow::RejectStepOrganizer` → implémenter
- [x] Spec `Documents::FinalizeOrganizer` (PDF + frozen) → implémenter

### Phase 4 — Contrôleurs & Vues (1 semaine)
- [x] Request specs contrôleurs → implémenter (`EntityScoped` concern)
- [x] Spec + implémentation composants `Ui::` (card, badge, button, empty_state, definition_list...)
- [x] Spec + implémentation composants `Entities::` (entity_card, member_row)
- [x] Spec + implémentation composants `Documents::` (card, metadata, file_list...)
- [x] Spec + implémentation composants `Workflow::` (steps, action_buttons)
- [x] Vues ERB = assemblage de composants (pas de HTML brut dans les vues)
- [x] Dashboard global (liste des entités de l'utilisateur)
- [x] Turbo Frames pour navigation partielle
- [x] Previews ViewComponent sur `/rails/view_components`
- [x] Workflow builder Stimulus (drag-and-drop)

### Phase 5 — Jobs & Notifications (3 jours)
- [x] `NotificationJob` + `NotificationMailer`
- [x] `PdfConversionJob` (avec fix sécurité LibreOffice)
- [x] Jobs récurrents (reminders, cleanup SharedLinks)

### Phase 6 — Tests système & Finalisation (3 jours)
- [ ] Tests système Capybara (golden path + edge cases)
- [ ] Coverage >80% (SimpleCov)
- [ ] RuboCop propre

### Phase 7 — Déploiement (1 jour)
- [ ] Configuration Kamal + Dockerfile
- [ ] Active Storage → S3 ou équivalent
- [ ] Premier déploiement

---

**DOCUMENTFLOW avec Rails 8 : TDD, OOP, Simple, Élégant, Puissant**
