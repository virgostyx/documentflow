# DOCUMENTFLOW - NOTE DE CONCEPT
## Système de Gestion de Flux Documentaire avec Rails 8

**Version:** 1.0  
**Date:** 9 Mars 2026  
**Framework:** Ruby on Rails 8  
**Client:** virgostyx

---

## RÉSUMÉ EXÉCUTIF

DocumentFlow est une application Rails 8 de gestion de flux documentaire avec validation multi-acteurs. Le système gère 
l'enregistrement de documents, leur validation selon un workflow structuré (RED → VISA → SIGN → EXP), les notifications 
par email, la conversion PDF à la finalisation, et le partage temporisé.

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
- **ViewComponent:** Composants réutilisables
- **TailwindCSS:** Framework CSS utility-first
- **Importmap:** Gestion des dépendances JS

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
├── models/                  # ActiveRecord models
│   ├── user.rb
│   ├── document.rb
│   ├── workflow_step.rb
│   ├── contact.rb
│   └── concerns/
├── controllers/             # Contrôleurs Rails
│   ├── documents_controller.rb
│   ├── workflows_controller.rb
│   └── api/
├── views/                   # Templates ERB
│   ├── documents/
│   ├── workflows/
│   └── layouts/
├── components/              # ViewComponents
│   ├── document_card_component.rb
│   ├── workflow_builder_component.rb
│   └── floating_label_component.rb
├── jobs/                    # Solid Queue jobs
│   ├── notification_job.rb
│   ├── pdf_conversion_job.rb
│   └── reminder_job.rb
├── services/                # Business logic
│   ├── workflow_state_machine.rb
│   ├── document_service.rb
│   └── pdf_converter.rb
├── mailers/                 # Action Mailer
│   └── notification_mailer.rb
└── javascript/              # Stimulus controllers
    ├── controllers/
    │   ├── workflow_builder_controller.js
    │   └── file_upload_controller.js
    └── application.js
```

---

## MODÈLE DE DONNÉES

### Modèles Principaux

**User** (Devise)
- Rôles : admin, manager, user, guest
- Authentification email

**Document**
- Référence : YYYY/##### (compteur global, reset annuel)
- États : draft, in_progress, signed, finalized, cancelled
- Frozen après finalisation

**WorkflowStep**
- Rôles : RED, VISA, SIGN, EXP
- Support VISA parallèles
- Statuts : pending, approved, rejected, skipped

**Contact**
- Carnet d'adresses
- Pour expéditeur/destinataire

**DocumentFile** (Active Storage)
- 25MB par fichier max
- 100MB par document max
- Formats : docx, xlsx, pptx, pdf, jpg, png, gif, txt, csv, zip, rar

**AuditLog**
- Trail complet de toutes les actions

**SharedLink**
- Tokens UUID
- Expiration 15 jours

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

### Floating Label Component

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
        @form.text_field(@field, 
          class: "peer block w-full px-3 pt-6 pb-2 border rounded-lg",
          placeholder: " "),
        tag.label(@label + (@required ? " *" : ""),
          for: @field,
          class: "floating-label")
      ])
    end
  end
end
```

```erb
<!-- Usage -->
<%= render FloatingLabelComponent.new(
  form: f, 
  field: :subject, 
  label: "Objet",
  required: true
) %>
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

### Pundit

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  def index?
    user.present?
  end
  
  def create?
    user.present? && !user.guest?
  end
  
  def update?
    return false if record.frozen?
    
    if record.draft?
      record.created_by == user
    elsif record.in_progress?
      record.current_step&.actor == user
    else
      false
    end
  end
  
  def destroy?
    user.admin?
  end
  
  def cancel?
    record.created_by == user && !record.finalized?
  end
end
```

---

## TESTS

### RSpec

```ruby
# spec/models/document_spec.rb
RSpec.describe Document, type: :model do
  describe "reference number generation" do
    it "generates unique sequential numbers" do
      doc1 = create(:document)
      doc2 = create(:document)
      
      expect(doc1.reference_number).to match(/\d{4}\/\d{5}/)
      expect(doc2.reference_number).not_to eq(doc1.reference_number)
    end
    
    it "resets counter each year" do
      travel_to Date.new(2025, 12, 31) do
        doc1 = create(:document)
        expect(doc1.reference_number).to start_with("2025/")
      end
      
      travel_to Date.new(2026, 1, 1) do
        doc2 = create(:document)
        expect(doc2.reference_number).to eq("2026/00001")
      end
    end
  end
  
  describe "workflow state machine" do
    let(:document) { create(:document, :with_workflow) }
    
    it "transitions from draft to in_progress" do
      expect { document.launch! }.to change { document.status }
        .from("draft").to("in_progress")
    end
    
    it "prevents RED from rejecting" do
      red_step = document.workflow_steps.find_by(role: 'RED')
      service = WorkflowStateMachine.new(document)
      
      expect {
        service.reject_step(red_step, reason: "test")
      }.to raise_error("RED cannot reject")
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

1. ✅ Setup Rails 8 application
2. ✅ Générer models avec migrations
3. ✅ Implémenter workflow state machine
4. ✅ Créer ViewComponents
5. ✅ Développer contrôleurs Stimulus
6. ✅ Tests RSpec complets
7. ✅ Déploiement avec Kamal

---

**DOCUMENTFLOW avec Rails 8 : Simple, Élégant, Puissant** 🚀
