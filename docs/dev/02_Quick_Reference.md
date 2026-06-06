# DOCUMENTFLOW - RÉFÉRENCE RAPIDE
## Commandes Essentielles Rails 8

---

## INSTALLATION RAPIDE

### Commande Unique (Automatisée)

```bash
bash setup_documentflow.sh
```

### Installation Manuelle

```bash
# Créer l'app
rails new documentflow --database=postgresql --css=tailwind --javascript=importmap

cd documentflow

# Ajouter les gems (voir Gemfile dans guide)
bundle install

# Créer DB
rails db:create
```

---

## DÉVELOPPEMENT QUOTIDIEN

### Démarrage (3 Terminaux)

```bash
# Terminal 1 - Serveur Rails
bin/rails server

# Terminal 2 - Solid Queue (jobs en arrière-plan)
bin/rails solid_queue:start

# Terminal 3 - TailwindCSS (compilation CSS)
bin/rails tailwindcss:watch
```

### Accès

- **Application**: http://localhost:3000
- **Jobs Dashboard**: http://localhost:3000/jobs
- **Emails**: S'ouvrent automatiquement (letter_opener)

---

## COMMANDES RAILS FRÉQUENTES

### Console

```bash
rails console                # Console développement
rails c                      # Raccourci
rails console --sandbox      # Mode sandbox (rollback auto)
```

### Base de Données

```bash
rails db:create              # Créer DB
rails db:migrate             # Exécuter migrations
rails db:rollback            # Annuler dernière migration
rails db:reset               # Drop + Create + Migrate + Seed
rails db:seed                # Charger seeds
rails db:migrate:status      # État des migrations
```

### Générateurs

```bash
# Model
rails generate model Document reference:string subject:string

# Controller
rails generate controller Documents index show new create

# Migration
rails generate migration AddFieldToModel field:type

# ViewComponent
rails generate component CardDocument document:Document

# Job
rails generate job NotificationJob

# Mailer
rails generate mailer NotificationMailer
```

### Routes

```bash
rails routes                 # Toutes les routes
rails routes -c documents    # Routes du contrôleur documents
rails routes -g workflow     # Routes contenant "workflow"
```

### Tests

```bash
bundle exec rspec                              # Tous les tests
bundle exec rspec spec/models/document_spec.rb # Un fichier
bundle exec rspec spec/models/document_spec.rb:10  # Une ligne
COVERAGE=true bundle exec rspec               # Avec coverage
```

### Assets

```bash
bin/rails assets:precompile  # Compiler assets (production)
bin/rails assets:clobber     # Nettoyer assets
```

---

## GÉNÉRATION DES MODELS DOCUMENTFLOW

### User (avec Devise)

```bash
rails generate devise:install
rails generate devise User
rails generate migration AddRoleToUsers role:string
```

### Contact

```bash
rails generate model Contact \
  first_name:string \
  last_name:string \
  email:string:uniq \
  is_active:boolean \
  created_by:references
```

### Document

```bash
rails generate model Document \
  reference_number:string:uniq \
  document_date:date \
  subject:string \
  status:string \
  is_frozen:boolean \
  finalized_at:datetime \
  created_by:references
```

### WorkflowStep

```bash
rails generate model WorkflowStep \
  document:references \
  order:integer \
  actor:references \
  role:string \
  status:string \
  is_parallel:boolean \
  parallel_group:integer \
  action_date:datetime \
  message:text \
  rejection_reason:text
```

### AuditLog

```bash
rails generate model AuditLog \
  document:references \
  user:references \
  action:string \
  details:jsonb \
  ip_address:inet
```

### SharedLink

```bash
rails generate model SharedLink \
  document:references \
  token:uuid \
  created_by:references \
  expires_at:datetime \
  accessed_count:integer \
  is_active:boolean
```

### Exécuter Migrations

```bash
rails db:migrate
```

---

## SOLID QUEUE

### Commandes

```bash
# Démarrer worker
bin/rails solid_queue:start

# Voir les jobs
rails console
SolidQueue::Job.all

# Interface web
# Accéder à http://localhost:3000/jobs
```

### Créer un Job

```bash
rails generate job Notification
```

```ruby
# app/jobs/notification_job.rb
class NotificationJob < ApplicationJob
  queue_as :default
  
  def perform(user_id, message)
    user = User.find(user_id)
    NotificationMailer.send_notification(user, message).deliver_now
  end
end
```

### Déclencher un Job

```ruby
# Immédiat
NotificationJob.perform_now(user.id, "Hello")

# Asynchrone
NotificationJob.perform_later(user.id, "Hello")

# Différé
NotificationJob.set(wait: 1.hour).perform_later(user.id, "Hello")
```

---

## VIEWCOMPONENTS

### Créer un Component

```bash
rails generate component FloatingLabel \
  form:object field:symbol label:string
```

### Utiliser un Component

```erb
<%= render FloatingLabelComponent.new(
  form: f,
  field: :subject,
  label: "Objet du document",
  required: true
) %>
```

---

## STIMULUS

### Créer un Controller

```bash
# Créer manuellement dans app/javascript/controllers/
touch app/javascript/controllers/workflow_builder_controller.js
```

```javascript
// app/javascript/controllers/workflow_builder_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["steps"]
  
  connect() {
    console.log("Workflow builder connected")
  }
  
  addStep(event) {
    event.preventDefault()
    // Logic here
  }
}
```

### Utiliser dans la Vue

```erb
<div data-controller="workflow-builder">
  <div data-workflow-builder-target="steps">
    <!-- Steps here -->
  </div>
  
  <button data-action="click->workflow-builder#addStep">
    Ajouter une étape
  </button>
</div>
```

---

## TURBO

### Turbo Frame

```erb
<!-- Vue index -->
<%= turbo_frame_tag "documents" do %>
  <%= render @documents %>
<% end %>

<!-- Vue show (remplace le frame) -->
<%= turbo_frame_tag "documents" do %>
  <%= render @document %>
<% end %>
```

### Turbo Stream

```ruby
# Controller
def create
  @document = Document.create(document_params)
  
  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to @document }
  end
end
```

```erb
<!-- create.turbo_stream.erb -->
<%= turbo_stream.prepend "documents", @document %>
<%= turbo_stream.update "form", "" %>
```

---

## TESTS RSPEC

### Structure de Test

```ruby
RSpec.describe Document, type: :model do
  describe "validations" do
    it { should validate_presence_of(:subject) }
  end
  
  describe "associations" do
    it { should belong_to(:created_by) }
  end
  
  describe "#method_name" do
    it "does something" do
      expect(result).to eq(expected)
    end
  end
end
```

### Factories

```ruby
# spec/factories/documents.rb
FactoryBot.define do
  factory :document do
    subject { Faker::Lorem.sentence }
    status { "draft" }
    association :created_by, factory: :user
    
    trait :finalized do
      status { "finalized" }
      is_frozen { true }
    end
  end
end
```

### Utilisation

```ruby
# Dans un test
let(:document) { create(:document) }
let(:finalized) { create(:document, :finalized) }
```

---

## DÉPLOIEMENT KAMAL

### Initialiser

```bash
kamal init
```

### Configuration Minimale

```yaml
# config/deploy.yml
service: documentflow
image: your-username/documentflow
servers:
  web:
    hosts:
      - your-vps-ip

env:
  secret:
    - RAILS_MASTER_KEY
```

### Déployer

```bash
kamal setup     # Premier déploiement
kamal deploy    # Déploiements suivants
kamal rollback  # Rollback
```

---

## RUBYMINE

### Raccourcis Utiles

| Action | Raccourci Mac | Raccourci Windows |
|--------|---------------|-------------------|
| Rechercher fichier | Cmd+Shift+O | Ctrl+Shift+N |
| Rechercher classe | Cmd+O | Ctrl+N |
| Rechercher texte | Cmd+Shift+F | Ctrl+Shift+F |
| Aller à définition | Cmd+B | Ctrl+B |
| Exécuter tests | Ctrl+Shift+R | Ctrl+Shift+F10 |
| Console Rails | Tools → Run Rails Console | |
| Générer... | Cmd+N | Alt+Insert |

### Run Configurations

Créer des configurations pour:
- Rails Server
- Solid Queue
- RSpec
- Rake Tasks

---

## CLAUDE CODE

### Installation

```bash
npm install -g @anthropic-ai/claude-code
```

### Utilisation

```bash
# Dans le dossier du projet
claude-code

# Ou pour une tâche spécifique
claude-code "Créer le contrôleur Documents avec CRUD complet"
```

### Exemples

```bash
# Générer code
claude-code "Implémenter WorkflowStateMachine avec AASM"

# Tests
claude-code "Générer tests RSpec pour Document model"

# Refactoring
claude-code "Extraire la logique de notification dans un service"

# Documentation
claude-code "Ajouter commentaires YARD au modèle Document"
```

---

## TROUBLESHOOTING

### Serveur ne démarre pas

```bash
# Vérifier le port
lsof -i :3000
kill -9 <PID>

# Relancer
bin/rails server
```

### Solid Queue ne fonctionne pas

```bash
# Vérifier la configuration
cat config/queue.yml

# Relancer
pkill -f solid_queue
bin/rails solid_queue:start
```

### Migrations en erreur

```bash
# Voir le statut
rails db:migrate:status

# Rollback
rails db:rollback STEP=1

# Reset complet
rails db:reset
```

### TailwindCSS ne compile pas

```bash
# Relancer le watcher
pkill -f tailwindcss
bin/rails tailwindcss:watch
```

### Assets manquants

```bash
# Recompiler
bin/rails assets:precompile

# Nettoyer le cache
bin/rails tmp:clear
```

---

## VARIABLES D'ENVIRONNEMENT

### Development

```bash
# .env (avec gem dotenv-rails)
DATABASE_URL=postgresql://localhost/documentflow_development
REDIS_URL=redis://localhost:6379/0
```

### Production

```bash
# Via Kamal ou credentials
rails credentials:edit

# Ou variables ENV
export RAILS_MASTER_KEY=xxx
export DATABASE_URL=xxx
```

---

## RESSOURCES

### Documentation Officielle

- Rails: https://guides.rubyonrails.org/
- Solid Queue: https://github.com/basecamp/solid_queue
- Turbo: https://turbo.hotwired.dev/
- Stimulus: https://stimulus.hotwired.dev/
- ViewComponent: https://viewcomponent.org/
- Kamal: https://kamal-deploy.org/

### Communauté

- Forum: https://discuss.rubyonrails.org/
- Reddit: r/rails
- Discord: Rails Discord Server

---

**DocumentFlow avec Rails 8 - Référence Complète** 📚
