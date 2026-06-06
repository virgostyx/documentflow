# DOCUMENTFLOW - GUIDE DE SETUP RAILS 8
## Installation et Configuration Complète

**Version:** 1.0  
**Date:** 9 Mars 2026  
**Framework:** Ruby on Rails 8.0

---

## TABLE DES MATIÈRES

1. [Prérequis](#prérequis)
2. [Installation Rails 8](#installation-rails-8)
3. [Création du Projet](#création-du-projet)
4. [Configuration](#configuration)
5. [Génération des Models](#génération-des-models)
6. [Setup Frontend](#setup-frontend)
7. [Tests](#tests)
8. [Démarrage](#démarrage)

---

## PRÉREQUIS

### Logiciels Requis

```bash
# Vérifier les versions
ruby --version          # 3.2.0 ou supérieur
rails --version         # 8.0.0 ou supérieur
psql --version          # PostgreSQL 15+
node --version          # Node.js 18+
git --version
```

### Installation des Prérequis (macOS)

```bash
# Ruby via rbenv
brew install rbenv ruby-build
rbenv install 3.2.2
rbenv global 3.2.2

# Rails 8
gem install rails -v '~> 8.0'

# PostgreSQL
brew install postgresql@17
brew services start postgresql@17

# Node.js
brew install node

# Autres dépendances
brew install imagemagick  # Pour Active Storage
brew install --cask libreoffice  # Pour conversion PDF
```

---

## INSTALLATION RAILS 8

### Option 1: Via RubyGems (Recommandé)

```bash
# Installer Rails 8
gem install rails --pre

# Vérifier l'installation
rails --version
# Devrait afficher: Rails 8.0.x
```

### Option 2: Via Bundler

```bash
# Créer Gemfile temporaire
echo "source 'https://rubygems.org'" > Gemfile
echo "gem 'rails', '~> 8.0'" >> Gemfile
bundle install
```

---

## CRÉATION DU PROJET

### Commande Complète

```bash
# Créer l'application avec toutes les options
rails new documentflow \
  --database=postgresql \
  --css=tailwind \
  --javascript=importmap \
  --skip-test \
  --skip-jbuilder

cd documentflow
```

### Explication des Options

- `--database=postgresql` : PostgreSQL comme base de données
- `--css=tailwind` : TailwindCSS intégré
- `--javascript=importmap` : Import maps pour JavaScript
- `--skip-test` : On utilisera RSpec
- `--skip-jbuilder` : Pas besoin de API builder

---

## CONFIGURATION

### 1. Gemfile - Ajouter les Gems

```ruby
# Gemfile

source "https://rubygems.org"

ruby "3.2.2"

# Rails 8 avec Solid Queue
gem "rails", "~> 8.0.0"
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"

# Base de données
gem "pg", "~> 1.5"

# Serveur
gem "puma", ">= 6.0"

# Assets
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

# Authentication
gem "devise"

# Authorization
gem "pundit"

# State Machine
gem "aasm"

# File Upload
gem "image_processing", "~> 1.2"

# PDF
gem "prawn"
gem "prawn-table"

# Recherche
gem "pg_search"

# Pagination
gem "kaminari"

# ViewComponents
gem "view_component"

# Performance
gem "bootsnap", require: false

# Background Jobs UI
gem "mission_control-jobs"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
end

group :development do
  gem "web-console"
  gem "rack-mini-profiler"
  gem "annotate"
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
end
```

### 2. Installer les Gems

```bash
bundle install
```

### 3. Configuration de la Base de Données

```yaml
# config/database.yml

default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: documentflow_development

test:
  <<: *default
  database: documentflow_test

production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
```

### 4. Créer les Bases de Données

```bash
rails db:create
# Created database 'documentflow_development'
# Created database 'documentflow_test'
```

### 5. Configuration Solid Queue

```yaml
# config/queue.yml

production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 5
      processes: 3
      polling_interval: 0.1

development:
  dispatchers:
    - polling_interval: 1
      batch_size: 100
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 1
```

```yaml
# config/recurring.yml

daily_reminders:
  class: DailyRemindersJob
  schedule: every day at 9am
  
cleanup_expired_links:
  class: CleanupExpiredLinksJob
  schedule: every day at 2am
```

### 6. Configuration Email (Development)

```ruby
# config/environments/development.rb

config.action_mailer.delivery_method = :letter_opener
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

```ruby
# Ajouter au Gemfile (development)
gem "letter_opener"
```

---

## GÉNÉRATION DES MODELS

### 1. Setup Devise pour User

```bash
# Installer Devise
rails generate devise:install
rails generate devise User

# Ajouter le champ role
rails generate migration AddRoleToUsers role:string
```

Modifier la migration:

```ruby
# db/migrate/xxx_add_role_to_users.rb

class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, default: 'user', null: false
    add_index :users, :role
  end
end
```

### 2. Générer Contact Model

```bash
rails generate model Contact \
  first_name:string \
  last_name:string \
  email:string:uniq \
  is_active:boolean \
  created_by:references
```

### 3. Générer Document Model

```bash
rails generate model Document \
  reference_number:string:uniq \
  document_date:date \
  subject:string \
  status:string \
  is_frozen:boolean \
  finalized_at:datetime \
  sender:references{polymorphic} \
  addressee:references{polymorphic} \
  created_by:references
```

### 4. Générer WorkflowStep Model

```bash
rails generate model WorkflowStep \
  document:references \
  order:integer \
  actor:references \
  role:string \
  is_parallel:boolean \
  parallel_group:integer \
  status:string \
  action_date:datetime \
  message:text \
  rejection_reason:text \
  notified_at:datetime \
  reminder_count:integer \
  last_reminder_at:datetime
```

### 5. Générer AuditLog Model

```bash
rails generate model AuditLog \
  document:references \
  user:references \
  action:string \
  details:jsonb \
  ip_address:inet
```

### 6. Générer SharedLink Model

```bash
rails generate model SharedLink \
  document:references \
  token:uuid \
  created_by:references \
  expires_at:datetime \
  accessed_count:integer \
  last_accessed_at:datetime \
  is_active:boolean
```

### 7. Exécuter les Migrations

```bash
rails db:migrate
```

---

## SETUP FRONTEND

### 1. Installation ViewComponent

```bash
rails generate view_component:install
```

### 2. Créer Floating Label Component

```bash
rails generate component FloatingLabel \
  form:object \
  field:symbol \
  label:string \
  type:symbol \
  required:boolean
```

Éditer le component:

```ruby
# app/components/floating_label_component.rb

class FloatingLabelComponent < ViewComponent::Base
  def initialize(form:, field:, label:, type: :text, required: false)
    @form = form
    @field = field
    @label = label
    @type = type
    @required = required
  end
  
  def call
    tag.div class: "relative" do
      safe_join([
        input_field,
        label_tag
      ])
    end
  end
  
  private
  
  def input_field
    @form.text_field(@field,
      type: @type,
      class: "peer block w-full px-3 pt-6 pb-2 border border-gray-300 rounded-lg " \
             "focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all",
      placeholder: " "
    )
  end
  
  def label_tag
    tag.label(
      label_text,
      for: @field,
      class: "absolute left-3 top-2 text-sm text-gray-500 transition-all " \
             "peer-placeholder-shown:top-4 peer-placeholder-shown:text-base " \
             "peer-focus:top-2 peer-focus:text-sm peer-focus:text-blue-500"
    )
  end
  
  def label_text
    @label + (@required ? tag.span(" *", class: "text-red-500") : "")
  end
end
```

### 3. Configuration Stimulus

```javascript
// app/javascript/controllers/index.js

import { application } from "./application"

// Import et enregistrer tous les contrôleurs
import WorkflowBuilderController from "./workflow_builder_controller"
import FileUploadController from "./file_upload_controller"

application.register("workflow-builder", WorkflowBuilderController)
application.register("file-upload", FileUploadController)
```

### 4. Créer Workflow Builder Controller

```javascript
// app/javascript/controllers/workflow_builder_controller.js

import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["steps", "template"]
  
  connect() {
    this.initSortable()
  }
  
  initSortable() {
    this.sortable = Sortable.create(this.stepsTarget, {
      animation: 150,
      handle: ".drag-handle",
      onEnd: this.updateOrder.bind(this)
    })
  }
  
  addStep(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML
      .replace(/NEW_RECORD/g, new Date().getTime())
    this.stepsTarget.insertAdjacentHTML('beforeend', content)
  }
  
  removeStep(event) {
    event.preventDefault()
    const step = event.target.closest('.workflow-step')
    step.remove()
    this.updateOrder()
  }
  
  updateOrder() {
    const steps = Array.from(this.stepsTarget.children)
    steps.forEach((step, index) => {
      const orderInput = step.querySelector('[name*="[order]"]')
      if (orderInput) orderInput.value = index + 1
    })
  }
}
```

### 5. Ajouter Sortable.js

```bash
# Via importmap
bin/importmap pin sortablejs
```

Ou ajouter à `config/importmap.rb`:

```ruby
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@1.15.2/+esm"
```

### 6. Configuration TailwindCSS

```css
/* app/assets/stylesheets/application.tailwind.css */

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  .btn-primary {
    @apply px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 
           focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors;
  }
  
  .btn-secondary {
    @apply px-4 py-2 border border-gray-300 rounded-lg text-gray-700 
           hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 
           transition-colors;
  }
  
  .floating-label {
    @apply absolute left-3 top-2 text-sm text-gray-500 transition-all
           peer-placeholder-shown:top-4 peer-placeholder-shown:text-base
           peer-focus:top-2 peer-focus:text-sm peer-focus:text-blue-500;
  }
}
```

---

## TESTS

### 1. Configuration RSpec

```bash
# Installer RSpec
rails generate rspec:install

# Configurer Factory Bot
mkdir spec/factories
```

### 2. Configuration RSpec

```ruby
# spec/rails_helper.rb

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  # Factory Bot
  config.include FactoryBot::Syntax::Methods
  
  # Database Cleaner
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.before do
    DatabaseCleaner.strategy = :transaction
  end
  
  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end
  
  config.before do
    DatabaseCleaner.start
  end
  
  config.after do
    DatabaseCleaner.clean
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

### 3. Créer Factories

```ruby
# spec/factories/users.rb

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }
    role { "user" }
    
    trait :admin do
      role { "admin" }
    end
    
    trait :manager do
      role { "manager" }
    end
    
    trait :guest do
      role { "guest" }
    end
  end
end
```

```ruby
# spec/factories/documents.rb

FactoryBot.define do
  factory :document do
    reference_number { "2026/00001" }
    document_date { Date.today }
    subject { Faker::Lorem.sentence }
    status { "draft" }
    is_frozen { false }
    association :sender, factory: :contact
    association :addressee, factory: :contact
    association :created_by, factory: :user
    
    trait :with_workflow do
      after(:create) do |document|
        create(:workflow_step, :red, document: document, order: 1)
        create(:workflow_step, :visa, document: document, order: 2)
        create(:workflow_step, :sign, document: document, order: 3)
        create(:workflow_step, :exp, document: document, order: 4)
      end
    end
    
    trait :in_progress do
      status { "in_progress" }
    end
    
    trait :finalized do
      status { "finalized" }
      is_frozen { true }
      finalized_at { Time.current }
    end
  end
end
```

### 4. Exemple de Test

```ruby
# spec/models/document_spec.rb

require 'rails_helper'

RSpec.describe Document, type: :model do
  describe "validations" do
    it { should validate_presence_of(:reference_number) }
    it { should validate_presence_of(:document_date) }
    it { should validate_presence_of(:subject) }
  end
  
  describe "associations" do
    it { should belong_to(:sender) }
    it { should belong_to(:addressee) }
    it { should belong_to(:created_by) }
    it { should have_many(:workflow_steps) }
    it { should have_many(:audit_logs) }
  end
  
  describe "#generate_reference_number" do
    it "generates unique sequential numbers" do
      doc1 = create(:document)
      doc2 = create(:document)
      
      expect(doc1.reference_number).to match(/\d{4}\/\d{5}/)
      expect(doc2.reference_number).not_to eq(doc1.reference_number)
    end
  end
  
  describe "state machine" do
    let(:document) { create(:document, :with_workflow) }
    
    it "transitions from draft to in_progress" do
      expect { document.launch! }
        .to change { document.status }
        .from("draft").to("in_progress")
    end
  end
end
```

---

## DÉMARRAGE

### 1. Démarrer le Serveur Rails

```bash
# Terminal 1 - Serveur Rails
bin/rails server

# Ou avec Puma directement
bundle exec puma -C config/puma.rb
```

### 2. Démarrer Solid Queue

```bash
# Terminal 2 - Solid Queue
bin/rails solid_queue:start
```

### 3. Démarrer TailwindCSS (Watch Mode)

```bash
# Terminal 3 - Tailwind
bin/rails tailwindcss:watch
```

### 4. Accéder à l'Application

```
Serveur Rails:          http://localhost:3000
Mission Control Jobs:   http://localhost:3000/jobs
Emails (Letter Opener): Ouvre automatiquement
```

---

## COMMANDES UTILES

### Rails Console

```bash
# Console de développement
rails console

# Console de production
rails console -e production

# Sandbox (rollback à la fin)
rails console --sandbox
```

### Migrations

```bash
# Créer une migration
rails generate migration AddFieldToModel field:type

# Exécuter les migrations
rails db:migrate

# Rollback
rails db:rollback

# Reset (drop + create + migrate)
rails db:reset

# Voir le statut
rails db:migrate:status
```

### Seeds

```bash
# Créer des données de test
rails db:seed

# Reset + seed
rails db:reset
```

### Routes

```bash
# Voir toutes les routes
rails routes

# Filtrer par contrôleur
rails routes -c documents

# Filtrer par URL
rails routes -g workflow
```

### Tests

```bash
# Tous les tests
bundle exec rspec

# Un fichier spécifique
bundle exec rspec spec/models/document_spec.rb

# Une ligne spécifique
bundle exec rspec spec/models/document_spec.rb:10

# Avec coverage
COVERAGE=true bundle exec rspec
```

### Qualité du Code

```bash
# RuboCop (linter)
bundle exec rubocop

# Auto-correct
bundle exec rubocop -a

# Annotations des models
bundle exec annotate
```

---

## STRUCTURE DU PROJET

```
documentflow/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── documents_controller.rb
│   │   └── workflows_controller.rb
│   ├── models/
│   │   ├── user.rb
│   │   ├── document.rb
│   │   ├── workflow_step.rb
│   │   └── concerns/
│   ├── views/
│   │   ├── layouts/
│   │   │   └── application.html.erb
│   │   ├── documents/
│   │   └── workflows/
│   ├── components/
│   │   ├── floating_label_component.rb
│   │   └── floating_label_component.html.erb
│   ├── services/
│   │   ├── workflow_state_machine.rb
│   │   └── document_service.rb
│   ├── jobs/
│   │   ├── notification_job.rb
│   │   └── pdf_conversion_job.rb
│   ├── mailers/
│   │   └── notification_mailer.rb
│   └── javascript/
│       ├── controllers/
│       │   ├── workflow_builder_controller.js
│       │   └── file_upload_controller.js
│       └── application.js
├── config/
│   ├── routes.rb
│   ├── database.yml
│   ├── queue.yml
│   ├── recurring.yml
│   ├── importmap.rb
│   └── environments/
├── db/
│   ├── migrate/
│   ├── schema.rb
│   └── seeds.rb
├── spec/
│   ├── models/
│   ├── requests/
│   ├── components/
│   ├── services/
│   ├── factories/
│   └── rails_helper.rb
├── Gemfile
├── Gemfile.lock
└── README.md
```

---

## DÉVELOPPEMENT AVEC RUBYMINE

### Configuration RubyMine

1. **Ouvrir le projet:**
   - File → Open → Sélectionner le dossier `documentflow`

2. **Configurer Ruby SDK:**
   - Preferences → Languages & Frameworks → Ruby SDK and Gems
   - Sélectionner Ruby 3.2.2

3. **Configurer Database:**
   - Database Tool Window → + → PostgreSQL
   - Connexion à `documentflow_development`

4. **Run Configurations:**
   - Run → Edit Configurations
   - + → Rails → Server
   - + → Rake → solid_queue:start

5. **Enable Gems:**
   - Tools → Bundler → Install gems

### Raccourcis Utiles RubyMine

- `Cmd + Shift + O` : Recherche de fichier
- `Cmd + O` : Recherche de classe
- `Cmd + Shift + F` : Recherche dans le projet
- `Ctrl + R` : Exécuter tests
- `Ctrl + D` : Débugger

---

## DÉVELOPPEMENT AVEC CLAUDE CODE

### Installation Claude Code

```bash
# Installer Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Ou via Homebrew
brew install claude-code
```

### Utilisation

```bash
# Dans le dossier du projet
cd documentflow

# Lancer Claude Code
claude-code

# Ou pour une tâche spécifique
claude-code "Créer le contrôleur documents avec actions CRUD"
```

### Exemples de Commandes

```bash
# Générer un component
claude-code "Créer ViewComponent pour afficher une carte de document"

# Implémenter une feature
claude-code "Ajouter la fonctionnalité de recherche full-text dans documents"

# Tests
claude-code "Générer tests RSpec pour WorkflowStateMachine"

# Refactoring
claude-code "Refactoriser DocumentsController pour extraire la logique dans un service"
```

---

## PROCHAINES ÉTAPES

### Phase 1: Models & Database
- [x] Setup Rails 8
- [x] Générer models
- [x] Exécuter migrations
- [ ] Ajouter validations
- [ ] Créer associations
- [ ] Implémenter state machine

### Phase 2: Controllers & Views
- [ ] Générer contrôleurs
- [ ] Créer routes
- [ ] Développer vues avec Turbo
- [ ] Implémenter ViewComponents

### Phase 3: Workflow
- [ ] Service WorkflowStateMachine
- [ ] Jobs de notification
- [ ] Conversion PDF
- [ ] Tests complets

### Phase 4: Frontend
- [ ] Stimulus controllers
- [ ] Workflow builder interactif
- [ ] Upload de fichiers
- [ ] Recherche live

### Phase 5: Déploiement
- [ ] Configuration Kamal
- [ ] Dockerfile
- [ ] Premier déploiement
- [ ] Monitoring

---

**Vous êtes prêt à développer DocumentFlow avec Rails 8! 🚀**

**Commandes de démarrage rapide:**
```bash
bundle install
rails db:create db:migrate
rails server               # Terminal 1
bin/rails solid_queue:start   # Terminal 2
bin/rails tailwindcss:watch   # Terminal 3
```

**Accès:**
- App: http://localhost:3000
- Jobs UI: http://localhost:3000/jobs
