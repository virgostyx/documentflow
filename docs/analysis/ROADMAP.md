# DocumentFlow - Roadmap d'Implémentation
**Date:** 31 juillet 2026  
**Version:** 1.0  
**Auteur:** Mistral Vibe  
**Public cible:** Équipe de développement, Product Owners, Team Leads  

---

## 📋 Table des Matières

1. [Introduction](#-introduction)
2. [Methodologie de Priorisation](#-méthodologie-de-priorisation)
3. [Sprint 1 - Sécurité et Stabilité](#-sprint-1---sécurité-et-stabilité-semaine-1-2)
4. [Sprint 2 - Workflows et Notifications](#-sprint-2---workflows-et-notifications-semaine-3-4)
5. [Sprint 3 - Optimisations et Robustesse](#-sprint-3---optimisations-et-robustesse-semaine-5-6)
6. [Backlog - Améliorations Avancées](#-backlog---améliorations-avancées)
7. [Dépendances entre Tâches](#-dépendances-entre-tâches)
8. [Critères d'Acceptation](#-critères-dacceptation)
9. [Risques et Atténuations](#-risques-et-atténuations)

---

## 🎯 Introduction

### Objectif

Cette roadmap définit **l'ordre d'implémentation** des corrections et améliorations identifiées dans l'analyse des complexités. Elle est conçue pour :

- **Stabiliser** l'application (corrections critiques en priorité)
- **Sécuriser** les intégrations externes (WOPI)
- **Optimiser** les performances (requêtes, notifications)
- **Améliorer** l'expérience utilisateur (workflows, numérotation)

### Principes Directeurs

```
▪ Urgence avant optimisation
▪ Sécurité avant fonctionnalité
▪ Stabilité avant performance
▪ Tests avant déploiement
▪ Documentation avant maintenance
```

### Calendrier Prévisionnel

```
Sprint 1: Semaines 1-2  → Sécurité & Stabilité
Sprint 2: Semaines 3-4  → Workflows & Notifications  
Sprint 3: Semaines 5-6  → Optimisations
Backlog:  Semaines 7+   → Améliorations Avancées
```

---

## 🔍 Méthodologie de Priorisation

### Matrice de Priorisation

| Critère | Poids | Urgent (🔴) | Haute (🟡) | Moyenne (🟢) |
|---------|-------|--------------|-------------|---------------|
| Impact Utilisateur | 40% | Bloquant | Majeur | Mineur |
| Risque Technique | 30% | Critique | Élevé | Faible |
| Effort d'Implémentation | 20% | < 2j | 2-5j | > 5j |
| ROI Métier | 10% | Immédiat | Court terme | Long terme |

### Score de Priorité

```
Score = (Impact × 0.4) + (Risque × 0.3) + (1/Effort × 20) + (ROI × 0.1)

Classement:
- Score > 0.8 → 🔴 Urgent (Sprint 1)
- 0.5 < Score ≤ 0.8 → 🟡 Haute (Sprint 2)
- Score ≤ 0.5 → 🟢 Moyenne (Sprint 3 ou Backlog)
```

### Résultats du Scoring

| Complexité | Problème | Score | Sprint | Effort Estimé |
|-----------|----------|-------|--------|---------------|
| WOPI | Authentification | **0.92** | 1 | 2 jours |
| WOPI | Conflit lock/check-out | **0.88** | 1 | 3 jours |
| Numérotation | Concurrence signature | **0.85** | 1 | 2 jours |
| Numérotation | Rollback transaction | **0.80** | 1 | 1 jour |
| Workflows | Étapes parallèles | **0.78** | 2 | 4 jours |
| Workflows | Rejet et retour | **0.75** | 2 | 3 jours |
| Notifications | Client déconnecté | **0.72** | 2 | 3 jours |
| Notifications | Duplication | **0.70** | 2 | 2 jours |
| WOPI | Gestion erreurs | **0.68** | 3 | 3 jours |
| WOPI | Détection formats | **0.65** | 3 | 2 jours |
| Polymorphic | N+1 queries | **0.62** | 3 | 3 jours |
| Workflows | Synchronisation AASM | **0.60** | 3 | 2 jours |

---

## 🔴 Sprint 1 - Sécurité et Stabilité (Semaine 1-2)

### Objectifs

- ✅ **Éliminer les risques de sécurité** (WOPI authentification)
- ✅ **Stabiliser les intégrations** (WOPI ↔ Check-out)
- ✅ **Corriger les bugs critiques** (numérotation concurrente)

### Tâches Détailées

#### 🔒 Tâche 1.1: Sécuriser l'Authentification WOPI (2 jours)

**Problème:** L'actuelle authentification WOPI peut permettre l'accès non autorisé aux documents.

**Solution:** Implémenter un système de tokens JWT signés avec expiration.

**Fichiers à modifier:**
```
app/services/wopi/generate_token_service.rb       # Nouveau
app/controllers/wopi_controller.rb               # Modifier
config/initializers/wopi.rb                      # Nouveau
spec/services/wopi/token_service_spec.rb        # Nouveau
```

**Code à implémenter:**

```ruby
# app/services/wopi/token_service.rb
module Wopi
  class TokenService
    SECRET_KEY = Rails.application.credentials.wopi[:secret_key]
    TOKEN_EXPIRY = 1.hour
    
    def self.generate_access_token(document, user)
      payload = {
        doc_id: document.id,
        entity_id: document.entity_id,
        user_id: user.id,
        permissions: calculate_permissions(document, user),
        exp: TOKEN_EXPIRY.from_now.to_i
      }
      
      JWT.encode(payload, SECRET_KEY, 'HS256')
    end
    
    def self.verify_token(token)
      decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' }).first
      
      # Vérifier que le document existe et est accessible
      document = Document.find_by(id: decoded['doc_id'])
      user = User.find_by(id: decoded['user_id'])
      
      return nil unless document && user
      return nil unless document.entity_id == decoded['entity_id']
      return nil unless permissions_valid?(document, user, decoded['permissions'])
      
      { document: document, user: user, permissions: decoded['permissions'].with_indifferent_access }
    rescue JWT::ExpiredSignature, JWT::DecodeError
      nil
    end
    
    private_class_method def self.calculate_permissions(document, user)
      perms = { read: true }
      
      if document.editable_by?(user)
        perms[:edit] = true
        perms[:save] = true
      end
      
      if document.deletable_by?(user)
        perms[:delete] = true
      end
      
      perms
    end
    
    private_class_method def self.permissions_valid?(document, user, permissions)
      # Recalculer les permissions et comparer
      expected = calculate_permissions(document, user)
      (permissions.to_set ⊆ expected.to_set) && (expected[:read] == true)
    end
  end
end
```

**Tests RSpec:**

```ruby
# spec/services/wopi/token_service_spec.rb
RSpec.describe Wopi::TokenService do
  let(:entity) { create(:entity) }
  let(:user) { create(:user, entity: entity) }
  let(:document) { create(:document, entity: entity, user: user) }
  
  describe '.generate_access_token' do
    it 'génère un token valide' do
      token = described_class.generate_access_token(document, user)
      expect(token).to be_present
    end
    
    it 'contient les bonnes informations' do
      token = described_class.generate_access_token(document, user)
      decoded = JWT.decode(token, described_class::SECRET_KEY, true, { algorithm: 'HS256' }).first
      
      expect(decoded['doc_id']).to eq(document.id)
      expect(decoded['user_id']).to eq(user.id)
      expect(decoded['entity_id']).to eq(entity.id)
    end
  end
  
  describe '.verify_token' do
    it 'valide un token correct' do
      token = described_class.generate_access_token(document, user)
      result = described_class.verify_token(token)
      
      expect(result[:document]).to eq(document)
      expect(result[:user]).to eq(user)
      expect(result[:permissions][:read]).to be true
    end
    
    it 'rejette un token expiré' do
      # Générer un token avec expiration dans le passé
      payload = { doc_id: document.id, entity_id: entity.id, user_id: user.id, exp: 1.hour.ago.to_i }
      token = JWT.encode(payload, described_class::SECRET_KEY, 'HS256')
      
      expect(described_class.verify_token(token)).to be_nil
    end
    
    it 'rejette un token avec mauvais document' do
      token = described_class.generate_access_token(document, user)
      # Modifier le document_id dans le token
      other_doc = create(:document, entity: entity)
      allow(Document).to receive(:find_by).and_return(other_doc)
      
      expect(described_class.verify_token(token)).to be_nil
    end
  end
end
```

**Critères d'acceptation:**
- [ ] Tokens JWT signés et sécurisés
- [ ] Expiration automatique après 1 heure
- [ ] Vérification de l'appartenance à l'entité
- [ ] Vérification des permissions réelles
- [ ] Tests unitaires à 100% de couverture
- [ ] Documentation API mise à jour

---

#### 🔒 Tâche 1.2: Synchronisation WOPI ↔ Check-out (3 jours)

**Problème:** Conflit entre le lock WOPI et le système de check-out interne.

**Solution:** Intégrer les deux systèmes avec une vérification mutuelle.

**Fichiers à modifier:**
```
app/models/document.rb                          # Modifier
app/services/document_checkout_service.rb       # Modifier
app/services/wopi/file_service.rb               # Nouveau
```

**Code à implémenter:**

```ruby
# app/services/wopi/file_service.rb
module Wopi
  class FileService
    def self.check_out_for_wopi(document, user)
      # Vérifier qu'un checkout existe déjà
      if document.checked_out?
        if document.checked_out_by?(user)
          # L'utilisateur a déjà le checkout, retourner le lock existant
          return { status: :already_checked_out, lock_id: document.checkout.lock_id }
        else
          # Quelqu'un d'autre a le checkout, empêcher l'accès WOPI
          return { status: :conflict, message: "Document checked out by #{document.checked_out_user.email}" }
        end
      end
      
      # Créer un checkout pour WOPI
      checkout = DocumentCheckout.create!(
        document: document,
        user: user,
        lock_id: SecureRandom.uuid,
        purpose: :wopi_edit,
        expires_at: 2.hours.from_now
      )
      
      { status: :success, lock_id: checkout.lock_id }
    end
    
    def self.check_in_from_wopi(document, lock_id, file_content)
      checkout = document.active_checkout
      
      return { status: :error, message: "No active checkout" } unless checkout
      return { status: :error, message: "Invalid lock" } unless checkout.lock_id == lock_id
      
      # Sauvegarder le fichier
      DocumentFileVersion.transaction do
        version = document.document_file_versions.create!(
          file: file_content,
          change_description: "WOPI edit via Collabora",
          version_number: document.document_file_versions.maximum(:version_number).to_i + 1
        )
        
        # Fermer le checkout
        checkout.update!(ended_at: Time.current, final_version: version)
      end
      
      { status: :success, version: version }
    end
    
    def self.get_lock_status(document, user)
      if document.checked_out?
        if document.checked_out_by?(user)
          { locked: true, lock_id: document.checkout.lock_id, owner: :current_user }
        else
          { locked: true, lock_id: document.checkout.lock_id, owner: :other_user, email: document.checked_out_user.email }
        end
      else
        { locked: false }
      end
    end
  end
end
```

**Modification du Document model:**

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # ...
  
  def wopi_edit_url(user)
    return nil unless editable_by?(user)
    
    # Vérifier le checkout
    checkout_status = Wopi::FileService.get_lock_status(self, user)
    
    case checkout_status[:owner]
    when :current_user
      # Utilisateur a déjà le lock, retourner l'URL WOPI
      generate_wopi_url(checkout_status[:lock_id])
    when :other_user
      # Document verrouillé par quelqu'un d'autre
      raise "Document locked by #{checkout_status[:email]}"
    else
      # Pas de lock, créer un checkout et retourner l'URL
      result = Wopi::FileService.check_out_for_wopi(self, user)
      
      if result[:status] == :conflict
        raise "Document locked by #{result[:message].split('by ').last}"
      end
      
      generate_wopi_url(result[:lock_id])
    end
  end
  
  private
  
  def generate_wopi_url(lock_id)
    # URL vers le controller WOPI qui gère l'authentification
    wopi_token = Wopi::TokenService.generate_access_token(self, user)
    
    "#{Rails.application.routes.url_helpers.wopi_url(host: Rails.application.config.wopi_host)}" +
      "?document_id=#{id}&lock_id=#{lock_id}&token=#{wopi_token}"
  end
end
```

**Critères d'acceptation:**
- [ ] Un seul utilisateur peut éditer à la fois (via WOPI ou check-out natif)
- [ ] Le lock WOPI est libéré automatiquement après 2 heures
- [ ] Le check-out natif bloque l'accès WOPI
- [ ] Le lock WOPI bloque le check-out natif
- [ ] Synchronisation des fichiers après sauvegarde WOPI
- [ ] Gestion des conflits avec messages clairs

---

#### 🔢 Tâche 1.3: Correction du Rollback de Numérotation (1 jour)

**Problème:** L'utilisation de `update_column` dans les callbacks contourne les validations et ne déclenche pas de rollback.

**Solution:** Toujours utiliser les méthodes ActiveRecord normales.

**Fichiers à modifier:**
```
app/models/document.rb                          # Modifier
app/services/documents/number_assignment_service.rb # Modifier
```

**Code à corriger:**

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # À REMPLACER:
  # before_save :assign_reference_number, if: -> { reference_number.blank? }
  
  # PAR:
  before_validation :assign_reference_number, if: -> { reference_number.blank? }
  
  # Et dans la méthode:
  # def assign_reference_number
  #   self.reference_number = NextDocumentNumberService.call(
  #     entity: entity,
  #     department: department,
  #     document_type: document_type
  #   )
  # end
  
  # NE PAS utiliser update_column dans les callbacks
end
```

**Service corrigé:**

```ruby
# app/services/documents/number_assignment_service.rb
module Documents
  class NumberAssignmentService
    def self.call(document:)
      new(document: document).call
    end
    
    def initialize(document:)
      @document = document
    end
    
    def call
      # Utiliser with_lock pour éviter les problèmes de concurrence
      department.with_lock do
        # Récupérer le prochain numéro
        last_doc = department.documents
          .where.not(reference_number: nil)
          .order(Arel.sql("SUBSTRING(reference_number FROM '#{department.prefix}[0-9]+')::bigint DESC"))
          .first
        
        next_number = last_doc ? extract_number(last_doc.reference_number) + 1 : 1
        
        # Construire le numéro complet
        "#{department.prefix}#{next_number.to_s.rjust(6, '0')}/#{document.document_date.year}"
      end
    end
    
    private
    
    def extract_number(reference)
      # Extraire le numéro de la référence
      match = reference.match(/(\d+)/)
      match ? match[1].to_i : 0
    end
    
    def department
      @document.department || @document.entity.departments.first!
    end
  end
end
```

**Test de rollback:**

```ruby
# spec/services/documents/number_assignment_service_spec.rb
RSpec.describe Documents::NumberAssignmentService do
  let(:entity) { create(:entity, prefix: 'DOC') }
  let(:department) { create(:department, entity: entity, prefix: 'DEP') }
  let(:user) { create(:user, entity: entity) }
  
  describe 'transaction rollback' do
    it 'annule la numérotation si la transaction échoue' do
      doc1 = build(:document, entity: entity, department: department, document_date: Date.today)
      
      expect {
        ActiveRecord::Base.transaction do
          doc1.save!
          doc1.update!(reference_number: nil) # Simuler une erreur qui force le rollback
          raise ActiveRecord::Rollback
        end
      }.to raise_error(ActiveRecord::Rollback)
      
      # Vérifier que le document n'existe pas
      expect(Document.where(id: doc1.id)).not_to exist
    end
    
    it 'assigne correctement le numéro après rollback' do
      doc1 = create(:document, entity: entity, department: department, document_date: Date.today)
      
      expect {
        ActiveRecord::Base.transaction do
          doc2 = build(:document, entity: entity, department: department, document_date: Date.today)
          doc2.save!
        end
      }.not_to raise_error
      
      doc2 = Document.order(created_at: :desc).first
      expect(doc2.reference_number).to eq('DEP000002/2026')
    end
  end
end
```

**Critères d'acceptation:**
- [ ] Aucun `update_column` ou `update_all` dans les callbacks de numérotation
- [ ] Utilisation exclusive de `with_lock` pour les opérations de numérotation
- [ ] Tests de rollback validés
- [ ] Vérification que les numéros restent cohérents après rollback

---

#### 📊 Sprint 1 - Récapitulatif

| Tâche | Effort | Priorité | Statut | Dépendances |
|-------|--------|----------|--------|-------------|
| 1.1 - Auth WOPI | 2j | 🔴 Urgent | ⏳ | Aucune |
| 1.2 - Sync WOPI/Checkout | 3j | 🔴 Urgent | ⏳ | 1.1 |
| 1.3 - Rollback Numérotation | 1j | 🔴 Urgent | ⏳ | Aucune |

**Total Sprint 1:** 6 jours  
**Capacité équipe (3 devs):** 6 jours → **Charge: 100%**

---

## 🟡 Sprint 2 - Workflows et Notifications (Semaine 3-4)

### Objectifs

- ✅ **Améliorer la gestion des workflows** (étapes parallèles, rejet)
- ✅ **Rendre les notifications fiables** (persistance, déduplication)
- ✅ **Automatiser la réassignation** des acteurs manquants

---

#### 🔄 Tâche 2.1: Gestion des Étapes Parallèles (4 jours)

**Problème:** Le système ne gère pas correctement les étapes parallèles (RED parallel, VISA multiple).

**Solution:** Implémenter un système de suivi des groupes parallèles.

**Fichiers à modifier:**
```
app/models/workflow_step.rb                     # Modifier
app/models/circuit_template_step.rb            # Modifier
app/services/workflows/parallel_processor.rb   # Nouveau
```

**Code à implémenter:**

```ruby
# app/services/workflows/parallel_processor.rb
module Workflows
  class ParallelProcessor
    def self.process_step_completion(workflow_step)
      new(workflow_step: workflow_step).call
    end
    
    def initialize(workflow_step:)
      @workflow_step = workflow_step
      @document = workflow_step.document
    end
    
    def call
      return unless parallel_group?
      
      # Vérifier si tous les acteurs du groupe parallèle ont complété leur étape
      if all_parallel_actors_completed?
        # Passer à l'étape suivante
        advance_to_next_step
      else
        # Mettre à jour le statut du groupe
        update_parallel_group_status
      end
    end
    
    private
    
    def parallel_group?
      @workflow_step.step_template.parallel_group_id.present?
    end
    
    def parallel_group
      @parallel_group ||= @workflow_step.document.workflow_steps
        .where(step_template: CircuitTemplateStep.where(parallel_group_id: @workflow_step.step_template.parallel_group_id))
    end
    
    def all_parallel_actors_completed?
      parallel_group.group_by(&:assignee_id).all? do |assignee_id, steps|
        steps.any?(&:completed?)
      end
    end
    
    def advance_to_next_step
      # Trouver la prochaine étape non-parallèle
      next_template = find_next_step_template
      return unless next_template
      
      # Créer les workflow_steps pour tous les assignees
      next_template.assignees.each do |assignee|
        WorkflowStep.create!(
          document: @document,
          step_template: next_template,
          assignee: assignee,
          status: :pending,
          position: next_template.position
        )
      end
      
      # Mettre à jour le statut du document si nécessaire
      update_document_status
    end
    
    def find_next_step_template
      current_position = @workflow_step.step_template.position
      next_position = current_position + 1
      
      @document.circuit_template.circuit_template_steps
        .where(position: next_position)
        .where(parallel_group_id: nil)
        .first
    end
    
    def update_document_status
      # Si toutes les étapes sont complétées, passer à signed
      if @document.all_workflow_steps_completed?
        @document.signed!
      end
    end
  end
end
```

**Migration nécessaire:**

```ruby
# db/migrate/[timestamp]_add_parallel_group_to_circuit_template_steps.rb
class AddParallelGroupToCircuitTemplateSteps < ActiveRecord::Migration[8.1]
  def change
    add_column :circuit_template_steps, :parallel_group_id, :uuid
    add_index :circuit_template_steps, :parallel_group_id
    
    # Pour les templates existants, générer des parallel_group_id
    reversible do |dir|
      dir.up do
        # Pour chaque template, identifier les groupes parallèles
        CircuitTemplate.find_each do |template|
          steps = template.circuit_template_steps.order(:position)
          
          # Identifier les groupes (steps avec même position = parallèle)
          grouped_steps = steps.group_by(&:position)
          
          grouped_steps.each do |position, group_steps|
            if group_steps.size > 1
              group_id = SecureRandom.uuid
              group_steps.each do |step|
                step.update!(parallel_group_id: group_id)
              end
            end
          end
        end
      end
    end
  end
end
```

**Critères d'acceptation:**
- [ ] Les étapes parallèles sont correctement groupées
- [ ] Le document ne passe à l'étape suivante que quand TOUS les acteurs parallèles ont complété
- [ ] Les notations sont envoyées uniquement quand le groupe est complété
- [ ] Interface utilisateur montre l'état de chaque acteur parallèle

---

#### 🔄 Tâche 2.2: Gestion du Rejet et Retour en Arrière (3 jours)

**Problème:** Quand un document est rejeté, il retourne en draft mais les workflow_steps ne sont pas correctement réinitialisés.

**Solution:** Implémenter un service de gestion du rejet avec transaction atomique.

**Fichiers à modifier:**
```
app/services/workflows/rejection_service.rb     # Nouveau
app/models/document.rb                          # Modifier
```

**Code à implémenter:**

```ruby
# app/services/workflows/rejection_service.rb
module Workflows
  class RejectionService
    def self.reject(document:, rejecter:, reason:)
      new(document: document, rejecter: rejecter, reason: reason).call
    end
    
    def initialize(document:, rejecter:, reason:)
      @document = document
      @rejecter = rejecter
      @reason = reason
      @errors = []
    end
    
    def call
      ActiveRecord::Base.transaction do
        validate_rejection
        execute_rejection
        notify_participants
      end
      
      { success: @errors.empty?, errors: @errors }
    rescue => e
      { success: false, errors: [e.message] }
    end
    
    private
    
    def validate_rejection
      # Vérifier que le document peut être rejeté
      unless @document.can_reject?
        @errors << "Document cannot be rejected in current state: #{@document.state}"
      end
      
      # Vérifier que le rejecter a le droit
      unless @document.rejectable_by?(@rejecter)
        @errors << "#{@rejecter.email} cannot reject this document"
      end
      
      raise ActiveRecord::Rollback if @errors.any?
    end
    
    def execute_rejection
      # Stocker l'historique
      @document.workflow_steps.where(status: [:in_progress, :pending]).each do |step|
        step.update!(
          status: :rejected,
          rejected_at: Time.current,
          rejected_by: @rejecter,
          rejection_reason: @reason
        )
      end
      
      # Créer un commentaire de rejet
      @document.comments.create!(
        user: @rejecter,
        body: "Document rejected: #{@reason}",
        comment_type: :rejection
      )
      
      # Mettre à jour l'état du document
      @document.draft!(rejection_reason: @reason)
      
      # Réinitialiser certains champs
      @document.update!(
        submitted_at: nil,
        first_submission_at: nil,
        current_approver_id: nil
      )
      
      # Vérifier si c'est un nouveau record de rejet
      @document.increment!(:rejection_count)
    end
    
    def notify_participants
      participants = @document.workflow_steps.map(&:assignee).compact.uniq
      
      participants.each do |participant|
        Notifications::DocumentRejectedJob.perform_later(
          document_id: @document.id,
          user_id: participant.id,
          rejecter_id: @rejecter.id,
          reason: @reason
        )
      end
      
      # Notifier l'auteur
      if @document.author && @document.author != @rejecter
        Notifications::DocumentRejectedJob.perform_later(
          document_id: @document.id,
          user_id: @document.author.id,
          rejecter_id: @rejecter.id,
          reason: @reason
        )
      end
    end
  end
end
```

**Modification du Document model:**

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # ...
  
  def can_reject?
    # Peut être rejeté depuis in_progress ou signed
    (in_progress? || signed?) && rejection_count < MAX_REJECTIONS
  end
  
  def rejectable_by?(user)
    # Le rejeteur doit être un approbateur dans le workflow
    workflow_steps.where(
      status: [:in_progress, :pending],
      assignee: user
    ).exists? || entity_admin?(user)
  end
  
  def entity_admin?(user)
    entity.entity_users.where(user: user, role: [:admin, :owner]).exists?
  end
  
  # Dans le AASM:
  aasm do
    # ...
    
    event :reject, after: :after_reject do
      transitions from: [:in_progress, :signed], to: :draft
    end
    
    # ...
  end
  
  def after_reject(reason: nil)
    # Appelé automatiquement par AASM
    Workflows::RejectionService.reject(
      document: self,
      rejecter: Current.user,
      reason: reason
    )
  end
end
```

**Critères d'acceptation:**
- [ ] Le document retourne en draft avec toutes les informations de rejet
- [ ] Toutes les workflow_steps en cours sont marquées comme rejetées
- [ ] Le compteur de rejet est incrémenté
- [ ] Les notifications sont envoyées à tous les participants
- [ ] Un commentaire de rejet est ajouté
- [ ] Transaction atomique (tout ou rien)

---

#### 📬 Tâche 2.3: Notifications Persistantes (3 jours)

**Problème:** Les notifications sont perdues si le client est déconnecté.

**Solution:** Implémenter un système de notification persistant.

**Fichiers à créer:**
```
app/models/notification.rb                     # Nouveau
app/services/notifications/persistent_dispatcher.rb # Nouveau
db/migrate/[timestamp]_create_notifications.rb  # Nouveau
```

**Migration:**

```ruby
# db/migrate/[timestamp]_create_notifications.rb
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, foreign_key: true
      t.references :notifiable, polymorphic: true
      t.string :notification_type, null: false
      t.jsonb :metadata
      t.boolean :read, default: false
      t.datetime :delivered_at
      t.timestamps
    end
    
    add_index :notifications, [:user_id, :read]  # Pour lister les non-lues
    add_index :notifications, [:user_id, :created_at]  # Pour la pagination
    add_index :notifications, :notifiable_id
    add_index :notifications, :notifiable_type
  end
end
```

**Modèle Notification:**

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :document, optional: true
  belongs_to :notifiable, polymorphic: true, optional: true
  
  enum notification_type: {
    document_assigned: 'document_assigned',
    document_rejected: 'document_rejected',
    document_signed: 'document_signed',
    document_finalized: 'document_finalized',
    comment_added: 'comment_added',
    checkout_requested: 'checkout_requested',
    checkout_approved: 'checkout_approved',
    wopi_edit_started: 'wopi_edit_started',
    generic: 'generic'
  }
  
  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc).limit(50) }
  scope :for_user, ->(user) { where(user: user) }
  
  # Pour le broadcast via Hotwire
  after_create_commit :broadcast_creation
  
  def broadcast_creation
    # Utiliser Turbo Streams pour pousser au client connecté
    if user.online?  # Nécessite un système de tracking online/offline
      ActionCable.server.broadcast(
        "user_#{user.id}_notifications",
        { 
          html: ApplicationController.render(
            partial: 'notifications/notification',
            locals: { notification: self }
          ),
          unread_count: user.notifications.unread.count
        }
      )
    end
  end
  
  def mark_as_read!
    update!(read: true)
  end
end
```

**Service de dispatch:**

```ruby
# app/services/notifications/persistent_dispatcher.rb
module Notifications
  class PersistentDispatcher
    def self.dispatch(user:, notification_type:, document: nil, notifiable: nil, metadata: {})
      new(
        user: user,
        notification_type: notification_type,
        document: document,
        notifiable: notifiable,
        metadata: metadata
      ).call
    end
    
    def initialize(user:, notification_type:, document: nil, notifiable: nil, metadata: {})
      @user = user
      @notification_type = notification_type
      @document = document
      @notifiable = notifiable
      @metadata = metadata
    end
    
    def call
      # Créer la notification en DB (persistante)
      notification = create_persistent_notification
      
      # Envoyer en temps réel si le user est connecté
      if user_online?
        broadcast_realtime(notification)
      end
      
      # Envoyer par email (optionnel, configurable)
      send_email_notification(notification) if send_email?
      
      notification
    end
    
    private
    
    def create_persistent_notification
      Notification.create!(
        user: @user,
        document: @document,
        notifiable: @notifiable,
        notification_type: @notification_type,
        metadata: @metadata,
        delivered_at: Time.current
      )
    end
    
    def user_online?
      # Vérifier si l'utilisateur a une session active
      # Cela nécessite un système de tracking des connections
      Redis.current.get("user:#{@user.id}:online") == 'true'
    end
    
    def broadcast_realtime(notification)
      NotificationBroadcastJob.perform_later(notification.id)
    end
    
    def send_email?
      # Vérifier les préférences utilisateur
      @user.notification_preferences.email?(@notification_type)
    end
    
    def send_email_notification(notification)
      NotificationMailer.with(notification: notification).send(@notification_type).deliver_later
    end
  end
end
```

**Job de broadcast:**

```ruby
# app/jobs/notification_broadcast_job.rb
class NotificationBroadcastJob < ApplicationJob
  queue_as :default
  
  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return unless notification
    
    # Envoyer via ActionCable
    if notification.user.online?
      ActionCable.server.broadcast(
        "user_#{notification.user_id}_notifications",
        notification.to_broadcast_json
      )
    end
  end
end
```

**Modification des jobs existants:**

```ruby
# app/jobs/notifications/document_rejected_job.rb
class Notifications::DocumentRejectedJob < ApplicationJob
  queue_as :default
  
  def perform(document_id:, user_id:, rejecter_id:, reason:)
    document = Document.find_by(id: document_id)
    user = User.find_by(id: user_id)
    rejecter = User.find_by(id: rejecter_id)
    
    return unless document && user
    
    # Créer notification persistante
    Notifications::PersistentDispatcher.dispatch(
      user: user,
      notification_type: :document_rejected,
      document: document,
      metadata: {
        rejecter_id: rejecter_id,
        rejecter_email: rejecter&.email,
        reason: reason
      }
    )
  end
end
```

**Critères d'acceptation:**
- [ ] Les notifications sont stockées en base de données
- [ ] Les notifications sont marquées comme lues/non-lues
- [ ] Les notifications persistent même si le user est déconnecté
- [ ] Les notifications sont affichées au reconnexion
- [ ] Compatibilité avec le système existant (Hotwire)
- [ ] Possibilité de désactiver les emails par type

---

#### 📊 Sprint 2 - Récapitulatif

| Tâche | Effort | Priorité | Statut | Dépendances |
|-------|--------|----------|--------|-------------|
| 2.1 - Étapes parallèles | 4j | 🟡 Haute | ⏳ | 1.2 |
| 2.2 - Rejet et retour | 3j | 🟡 Haute | ⏳ | 1.1 |
| 2.3 - Notifications persistantes | 3j | 🟡 Haute | ⏳ | Aucune |

**Total Sprint 2:** 10 jours  
**Capacité équipe (3 devs):** 18 jours → **Charge: 55%**

---

## 🟢 Sprint 3 - Optimisations et Robustesse (Semaine 5-6)

### Objectifs

- ✅ **Optimiser les performances** (WOPI, requêtes)
- ✅ **Améliorer la robustesse** (gestion des erreurs)
- ✅ **Préparer les améliorations futures**

---

#### ⚡ Tâche 3.1: Détection des Formats WOPI (2 jours)

**Problème:** Certains formats de fichiers ne sont pas correctement détectés pour WOPI.

**Solution:** Implémenter un service de détection robuste.

**Fichiers à créer:**
```
app/services/wopi/format_detector.rb           # Nouveau
spec/services/wopi/format_detector_spec.rb   # Nouveau
```

**Code à implémenter:**

```ruby
# app/services/wopi/format_detector.rb
module Wopi
  class FormatDetector
    # Liste des formats supportés par Collabora
    SUPPORTED_FORMATS = %w[
      docx xlsx pptx doc xls ppt odt ods odp txt rtf csv
      pdf  # Support limité
    ].freeze
    
    # MIME types correspondants
    SUPPORTED_MIME_TYPES = %w[
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/vnd.openxmlformats-officedocument.presentationml.presentation
      application/msword
      application/vnd.ms-excel
      application/vnd.ms-powerpoint
      application/vnd.oasis.opendocument.text
      application/vnd.oasis.opendocument.spreadsheet
      application/vnd.oasis.opendocument.presentation
      text/plain
      text/rtf
      text/csv
      application/pdf
    ].freeze
    
    def self.supported?(file)
      new(file: file).supported?
    end
    
    def self.wopi_extension(file)
      new(file: file).wopi_extension
    end
    
    def initialize(file:)
      @file = file
    end
    
    def supported?
      return false unless @file.attached?
      
      by_filename || by_content_type
    end
    
    def wopi_extension
      return nil unless supported?
      
      # Retourner l'extension à utiliser pour WOPI
      ext = @file.blob.filename.extension.downcase
      
      # Mapper les extensions complexes
      extension_mapping[ext] || ext
    end
    
    private
    
    def by_filename
      ext = @file.blob.filename.extension.downcase
      SUPPORTED_FORMATS.include?(ext)
    end
    
    def by_content_type
      content_type = @file.blob.content_type.downcase
      SUPPORTED_MIME_TYPES.any? { |mime| content_type.start_with?(mime) }
    end
    
    def extension_mapping
      {
        'txt' => 'txt',
        'rtf' => 'rtf',
        'csv' => 'csv',
        'pdf' => 'pdf'
      }
    end
  end
end
```

**Validation dans le Document model:**

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # ...
  
  validate :wopi_file_format, if: -> { file_attached? && wopi_enabled? }
  
  private
  
  def wopi_file_format
    if file.attached? && wopi_enabled? && !Wopi::FormatDetector.supported?(file)
      errors.add(:file, "Format not supported for WOPI editing: #{file.blob.filename}")
    end
  end
  
  def wopi_enabled?
    entity.wopi_enabled?
  end
end
```

**Critères d'acceptation:**
- [ ] Détection par extension de fichier
- [ ] Détection par MIME type
- [ ] Liste des formats supportés configurable
- [ ] Retour de l'extension WOPI appropriée
- [ ] Validation avant upload
- [ ] Tests pour tous les formats supportés

---

#### ⚡ Tâche 3.2: Gestion des Erreurs Collabora (3 jours)

**Problème:** Les erreurs Collabora ne sont pas gérées de manière robuste.

**Solution:** Implémenter un système de retry intelligent et de fallback.

**Fichiers à créer:**
```
app/services/wopi/error_handler.rb              # Nouveau
app/services/wopi/retry_service.rb              # Nouveau
```

**Code à implémenter:**

```ruby
# app/services/wopi/error_handler.rb
module Wopi
  class ErrorHandler
    # Classification des erreurs
    RETRYABLE_ERRORS = %w[
      WOPI_LOCK_CONFLICT
      WOPI_FILE_NOT_FOUND
      WOPI_TOKEN_EXPIRED
      WOPI_SERVER_UNAVAILABLE
      NETWORK_TIMEOUT
    ].freeze
    
    PERMANENT_ERRORS = %w[
      WOPI_UNSUPPORTED_FORMAT
      WOPI_PERMISSION_DENIED
      WOPI_INVALID_TOKEN
    ].freeze
    
    def self.handle(error, context = {})
      new(error: error, context: context).call
    end
    
    def initialize(error:, context: {})
      @error = error
      @context = context
      @document = context[:document]
      @user = context[:user]
      @retry_count = context[:retry_count] || 0
    end
    
    def call
      case error_classification
      when :retryable
        handle_retryable
      when :permanent
        handle_permanent
      when :unknown
        handle_unknown
      end
    end
    
    private
    
    def error_classification
      error_code = extract_error_code
      
      if RETRYABLE_ERRORS.include?(error_code)
        :retryable
      elsif PERMANENT_ERRORS.include?(error_code)
        :permanent
      else
        :unknown
      end
    end
    
    def extract_error_code
      return @context[:error_code] if @context[:error_code]
      
      case @error
      when StandardError
        @error.message.split(':').first.upcase
      when Hash
        @error['error_code'] || @error[:error_code]
      else
        'UNKNOWN'
      end
    end
    
    def handle_retryable
      max_retries = @context[:max_retries] || 3
      
      if @retry_count >= max_retries
        log_error("Max retries exceeded for #{@context[:operation]}")
        notify_user(:wopi_error_max_retries, @error.message)
        :max_retries_exceeded
      else
        delay = calculate_delay
        Wopi::RetryService.schedule(
          operation: @context[:operation],
          document: @document,
          user: @user,
          retry_count: @retry_count + 1,
          max_retries: max_retries,
          delay: delay,
          error: @error
        )
        :retry_scheduled
      end
    end
    
    def calculate_delay
      # Exponential backoff
      base = 2
      max_delay = 30.minutes
      
      delay_seconds = [base ** @retry_count, 60].min
      [delay_seconds.seconds, max_delay].min
    end
    
    def handle_permanent
      log_error("Permanent error: #{extract_error_code}")
      notify_user(:wopi_permanent_error, permanent_error_message)
      :permanent_error
    end
    
    def handle_unknown
      log_error("Unknown WOPI error: #{@error.class} - #{@error.message}")
      notify_user(:wopi_unknown_error, @error.message)
      :unknown_error
    end
    
    def notify_user(notification_type, message)
      Notifications::PersistentDispatcher.dispatch(
        user: @user,
        notification_type: notification_type,
        document: @document,
        metadata: { error: message, context: @context.except(:user, :document) }
      )
    end
    
    def log_error(message)
      Rails.logger.error("[WOPI] #{message} - Document: #{@document&.id}, User: #{@user&.id}")
    end
    
    def permanent_error_message
      code = extract_error_code
      
      case code
      when 'WOPI_UNSUPPORTED_FORMAT'
        "Le format de ce fichier n'est pas supporté pour l'édition en ligne"
      when 'WOPI_PERMISSION_DENIED'
        "Vous n'avez pas la permission d'éditer ce document"
      else
        "Une erreur est survenue avec l'édition en ligne: #{code}"
      end
    end
  end
end
```

**Service de retry:**

```ruby
# app/services/wopi/retry_service.rb
module Wopi
  class RetryService
    def self.schedule(operation:, document:, user:, retry_count:, max_retries:, delay:, error:)
      job_class = retry_job_class(operation)
      
      job_class.set(queue: :wopi_retries)
        .perform_later(
          document_id: document&.id,
          user_id: user&.id,
          retry_count: retry_count,
          max_retries: max_retries,
          error: error.as_json,
          scheduled_at: delay.from_now
        )
    end
    
    def self.retry_job_class(operation)
      case operation
      when :check_out
        Wopi::RetryCheckoutJob
      when :file_sync
        Wopi::RetryFileSyncJob
      when :token_refresh
        Wopi::RetryTokenRefreshJob
      else
        Wopi::RetryGenericJob
      end
    end
    
    # Job de base
    class BaseRetryJob < ApplicationJob
      def perform(document_id:, user_id:, retry_count:, max_retries:, error:, scheduled_at:)
        document = Document.find_by(id: document_id)
        user = User.find_by(id: user_id)
        
        return unless document && user
        
        # Reconstruire l'erreur
        error_obj = reconstruct_error(error)
        
        # Réessayer l'opération
        begin
          execute_operation(document, user)
        rescue => new_error
          # Gérer l'erreur
          Wopi::ErrorHandler.handle(
            new_error,
            context: {
              document: document,
              user: user,
              retry_count: retry_count,
              max_retries: max_retries,
              error: error_obj
            }
          )
        end
      end
      
      def execute_operation(document, user)
        raise NotImplementedError, "Must be implemented by subclass"
      end
      
      def reconstruct_error(error_data)
        return nil unless error_data
        
        case error_data['class']
        when 'Wopi::LockConflictError'
          Wopi::LockConflictError.new(error_data['message'])
        when 'Wopi::TokenExpiredError'
          Wopi::TokenExpiredError.new(error_data['message'])
        else
          StandardError.new(error_data['message'])
        end
      end
    end
  end
end
```

**Jobs spécifiques:**

```ruby
# app/jobs/wopi/retry_checkout_job.rb
class Wopi::RetryCheckoutJob < Wopi::RetryService::BaseRetryJob
  def execute_operation(document, user)
    Wopi::FileService.check_out_for_wopi(document, user)
  end
end

# app/jobs/wopi/retry_file_sync_job.rb
class Wopi::RetryFileSyncJob < Wopi::RetryService::BaseRetryJob
  def execute_operation(document, user)
    Wopi::FileSyncService.sync_from_wopi(document)
  end
end
```

**Critères d'acceptation:**
- [ ] Classification des erreurs (retryable vs permanent)
- [ ] Retour exponentiel (backoff)
- [ ] Nombre maximal de retries configurable
- [ ] Notifications utilisateur appropriées
- [ ] Logging détaillé des erreurs
- [ ] Jobs de retry dédiés par type d'opération

---

#### ⚡ Tâche 3.3: Optimisation des Requêtes Polymorphiques (3 jours)

**Problème:** Les requêtes polymorphiques (sender/addressee) génèrent des N+1 queries.

**Solution:** Implémenter du caching et des optimisations de requêtes.

**Fichiers à modifier:**
```
app/models/concerns/party_assignable.rb         # Modifier
app/models/document.rb                          # Modifier
```

**Code à implémenter:**

```ruby
# app/models/concerns/party_assignable.rb
module PartyAssignable
  extend ActiveSupport::Concern
  
  included do
    # Cache des objets polymorphiques
    has_many :party_cache_entries, as: :cacheable, dependent: :delete_all
  end
  
  class_methods do
    # Méthode pour charger les parties avec eager loading
    def with_parties
      # Pré-charger tous les users et contacts référencés
      party_ids = select(:sender_id, :sender_type, :addressee_id, :addressee_type)
        .flat_map { |d| [d.sender_id, d.addressee_id] }.compact.uniq
      
      party_types = party_ids.each_with_object({}) do |id, hash|
        # Déterminer le type pour chaque ID
        if PartyAssignable::User.where(id: id).exists?
          hash[id] = 'User'
        elsif PartyAssignable::Contact.where(id: id).exists?
          hash[id] = 'Contact'
        end
      end
      
      # Grouper par type pour des requêtes efficaces
      user_ids = party_types.select { |_, v| v == 'User' }.keys
      contact_ids = party_types.select { |_, v| v == 'Contact' }.keys
      
      preloaded = all
      preloaded = preloaded.preload(:sender, :addressee) if defined?(ActiveRecord::Preloader)
      
      # Utiliser includes pour éviter N+1
      includes_user = user_ids.any? ? User.where(id: user_ids) : User.none
      includes_contact = contact_ids.any? ? Contact.where(id: contact_ids) : Contact.none
      
      preloaded.includes(:sender => [includes_user, includes_contact].flatten)
    end
  end
  
  # Méthode optimisée pour obtenir le nom de la partie
  def party_name(party_type, party_id)
    return nil unless party_type && party_id
    
    cache_key = "#{party_type}_#{party_id}_name"
    
    # Vérifier le cache Redis d'abord
    cached = Redis.current.get(cache_key)
    return cached if cached
    
    # Vérifier le cache DB
    cache_entry = party_cache_entries
      .where(party_type: party_type, party_id: party_id)
      .first
    
    if cache_entry && cache_entry.expires_at > Time.current
      return cache_entry.cached_value
    end
    
    # Charger la partie
    party = party_type.constantize.find_by(id: party_id)
    return nil unless party
    
    name = party.respond_to?(:full_name) ? party.full_name : party.name
    
    # Mettre en cache
    cache_expiry = 1.hour.from_now
    
    # Cache Redis (rapide)
    Redis.current.setex(cache_key, 3600, name)
    
    # Cache DB (persistant)
    party_cache_entries.create!(
      party_type: party_type,
      party_id: party_id,
      cached_value: name,
      expires_at: cache_expiry
    )
    
    name
  end
  
  def sender_name
    party_name(sender_type, sender_id)
  end
  
  def addressee_name
    party_name(addressee_type, addressee_id)
  end
end
```

**Modification du Document model:**

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # ...
  
  # Utiliser l'optimisation des parties
  scope :with_parties_eager, -> {
    # Pré-charger les relations polymorphiques
    includes(:sender, :addressee)
  }
  
  # Méthode pour obtenir tous les documents avec leurs parties pré-chargées
  def self.with_all_parties
    # Approche 1: Utiliser les scopes existants
    with_parties
  end
  
  # Méthode optimisée pour les listes
  def self.for_list_with_parties
    # Sélectionner uniquement les champs nécessaires
    select(
      :id, :reference_number, :subject, :state, :document_date,
      :sender_id, :sender_type, :addressee_id, :addressee_type,
      :created_at, :updated_at
    ).with_parties
  end
end
```

**Service de cache dédié:**

```ruby
# app/services/party_cache_service.rb
class PartyCacheService
  CACHE_EXPIRY = 1.hour
  
  def self.get(party_type, party_id, field: :name)
    return nil unless party_type && party_id
    
    cache_key = "party:#{party_type}:#{party_id}:#{field}"
    
    # Vérifier Redis
    cached = Redis.current.get(cache_key)
    return cached if cached
    
    # Charger depuis DB
    party_class = party_type.safe_constantize
    return nil unless party_class
    
    party = party_class.find_by(id: party_id)
    return nil unless party
    
    value = party.public_send(field) rescue party.send(field)
    
    # Mettre en cache
    Redis.current.setex(cache_key, CACHE_EXPIRY.to_i, value)
    
    value
  end
  
  def self.invalidate(party_type, party_id)
    # Invalider toutes les clés pour cette partie
    keys = Redis.current.keys("party:#{party_type}:#{party_id}:*")
    keys.each { |k| Redis.current.del(k) }
  end
  
  def self.invalidate_party(party)
    invalidate(party.class.name, party.id)
  end
end
```

**Middleware pour invalider le cache:**

```ruby
# app/middleware/party_cache_invalidator.rb
class PartyCacheInvalidator
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Après la requête, invalider le cache si nécessaire
    response = @app.call(env)
    
    # Vérifier si la requête a modifié un User ou Contact
    if modified_party?(request)
      invalidate_affected_caches(request)
    end
    
    response
  end
  
  private
  
  def modified_party?(request)
    return false unless request.post? || request.put? || request.patch? || request.delete?
    
    path = request.path
    path.include?('/users/') || path.include?('/contacts/')
  end
  
  def invalidate_affected_caches(request)
    # Extraire l'ID de la partie modifiée
    id = request.path.split('/').last
    
    if request.path.include?('/users/')
      PartyCacheService.invalidate('User', id)
    elsif request.path.include?('/contacts/')
      PartyCacheService.invalidate('Contact', id)
    end
  end
end
```

**Critères d'acceptation:**
- [ ] Cache Redis pour les noms des parties
- [ ] Cache DB comme fallback
- [ ] Eager loading des relations polymorphiques
- [ ] Invalidations de cache automatiques
- [ ] Réduction mesurable des N+1 queries
- [ ] Tests de performance avant/après

---

#### 📊 Sprint 3 - Récapitulatif

| Tâche | Effort | Priorité | Statut | Dépendances |
|-------|--------|----------|--------|-------------|
| 3.1 - Détection formats | 2j | 🟢 Moyenne | ⏳ | 1.2 |
| 3.2 - Gestion erreurs | 3j | 🟢 Moyenne | ⏳ | 1.1, 1.2 |
| 3.3 - Optimisation queries | 3j | 🟢 Moyenne | ⏳ | Aucune |

**Total Sprint 3:** 8 jours  
**Capacité équipe (3 devs):** 18 jours → **Charge: 44%**

---

## 🟣 Backlog - Améliorations Avancées

### Tâches Planifiées (Priorité Descendante)

| # | Tâche | Effort | Priorité | Sprint Cible | Description |
|---|-------|--------|----------|--------------|-------------|
| B1 | Migration format numéros | 5j | 🟢 | Sprint 4 | Migrer vers un format plus flexible (YYYY-DEP-000001) |
| B2 | Table Party unifiée | 8j | 🟢 | Sprint 4 | Remplacer sender_type/id par une table de jointure |
| B3 | Queue notifications async | 3j | 🟢 | Sprint 4 | Découpler les notifications de la requête HTTP |
| B4 | WOPI async save | 5j | 🟡 | Sprint 5 | Sauvegarde asynchrone des fichiers WOPI |
| B5 | Workflow templates UI | 5j | 🟡 | Sprint 5 | Interface de création de templates |
| B6 | Document versioning UI | 3j | 🟢 | Sprint 5 | Interface de gestion des versions |
| B7 | Audit log export | 2j | 🟢 | Sprint 5 | Export CSV/PDF des logs d'audit |
| B8 | Multi-language support | 10j | 🟡 | Sprint 6 | Internationalisation complète |
| B9 | API REST v1 | 15j | 🟡 | Sprint 7+ | API publique pour intégration |
| B10 | Webhooks | 8j | 🟡 | Sprint 7+ | Webhooks pour notifications externes |

### Détails des Tâches Backlog

---

#### B1: Migration du Format de Numérotation (5 jours)

**Objectif:** Passer d'un format `DEP000001/2026` à `2026-DEP-000001`

**Défis:**
- Migration des documents existants
- Maintien de la compatibilité
- Performance de la migration

**Approche:**
1. Créer un nouveau format optionnel
2. Migrer par batches
3. Nettoyer l'ancien format après migration

---

#### B2: Table Party Unifiée (8 jours)

**Objectif:** Remplacer les associations polymorphiques (sender_type/sender_id, addressee_type/addressee_id) par une table de jointure dédiée.

**Avantages:**
- Requêtes plus simples
- Meilleure performance
- Facilité de maintenance
- Support de validations complexes

**Structure proposée:**

```sql
CREATE TABLE parties (
  id UUID PRIMARY KEY,
  partyable_type VARCHAR NOT NULL,
  partyable_id UUID NOT NULL,
  role VARCHAR NOT NULL, -- sender, addressee, cc, bcc
  entity_id UUID,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Pour User parties
CREATE TABLE user_parties (
  id UUID PRIMARY KEY REFERENCES parties(id),
  user_id UUID NOT NULL REFERENCES users(id)
);

-- Pour Contact parties
CREATE TABLE contact_parties (
  id UUID PRIMARY KEY REFERENCES parties(id),
  contact_id UUID NOT NULL REFERENCES contacts(id)
);
```

**Migration:**
1. Créer les nouvelles tables
2. Migrer les données existantes
3. Mettre à jour le code pour utiliser les nouvelles associations
4. Supprimer les anciennes colonnes (après validation)

---

#### B3: Queue de Notifications Asynchrone (3 jours)

**Objectif:** Découpler complètement les notifications de la requête HTTP pour améliorer la performance.

**Solution:**
- Utiliser Solid Queue pour les notifications
- Stocker les notifications en attente
- Traiter en arrière-plan

**Avantages:**
- Réduction du temps de réponse HTTP
- Meilleure résilience aux pannes
- Possibilité de priorisation

---

## 🔗 Dépendances entre Tâches

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Sprint 1       │────▶│   Sprint 2       │────▶│   Sprint 3       │
│ 1.1 Auth WOPI    │     │ 2.1 Étapes       │     │ 3.1 Détection    │
│ 1.2 Sync Check.  │     │    parallèles    │     │    formats      │
│ 1.3 Rollback     │     │ 2.2 Rejet        │     │ 3.2 Erreurs     │
└────────┬────────┘     │ 2.3 Notifications│     │ 3.3 Optimisation│
         │               └────────┬────────┘     └─────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────────────────┐
│                    Sprint 4+                           │
│         Backlog: B1, B2, B3, B4, ...                   │
└─────────────────────────────────────────────────────┘

Légende:
  ▶ = Dépendance directe
  ┴─ = Peut commencer en parallèle
```

**Détails des dépendances:**

| Tâche | Dépend de | Blocke |
|-------|-----------|--------|
| 1.2 Sync WOPI/Checkout | 1.1 Auth WOPI | 2.1, 2.2, 3.1, 3.2 |
| 2.1 Étapes parallèles | 1.2 Sync WOPI | 3.3 |
| 2.2 Rejet | 1.1 Auth WOPI | Aucune |
| 2.3 Notifications | Aucune | 3.3 |
| 3.1 Détection formats | 1.2 Sync WOPI | Aucune |
| 3.2 Gestion erreurs | 1.1, 1.2 | Aucune |
| 3.3 Optimisation | 2.1 | Aucune |
| B1 Migration format | Aucune | B2 |
| B2 Table Party | B1 | B3 |

---

## ✅ Critères d'Acceptation par Sprint

### Sprint 1 - Complétude

- [ ] Toutes les tâches 1.1, 1.2, 1.3 terminées
- [ ] Tests unitaires > 90% de couverture pour le code ajouté
- [ ] Tests d'intégration pour les scénarios critiques
- [ ] Documentation mise à jour
- [ ] Déploiement en staging validé
- [ ] Aucune régression en production

### Sprint 2 - Complétude

- [ ] Toutes les tâches 2.1, 2.2, 2.3 terminées
- [ ] Workflows parallèles fonctionnels
- [ ] Système de rejet opérationnel
- [ ] Notifications persistantes déployées
- [ ] Tests de bout en bout validés
- [ ] Documentation utilisateur mise à jour

### Sprint 3 - Complétude

- [ ] Toutes les tâches 3.1, 3.2, 3.3 terminées
- [ ] Détection des formats robuste
- [ ] Gestion des erreurs WOPI améliorée
- [ ] Optimisation des requêtes validée (benchmarks)
- [ ] Amélioration des performances mesurables

---

## ⚠️ Risques et Atténuations

### Risques Techniques

| Risque | Probabilité | Impact | Atténuation |
|--------|-------------|--------|-------------|
| Migration de données corrompue | Moyenne | Élevé | Sauvegardes complètes avant migration, tests de rollback |
| Incompatibilité WOPI avec nouvelle version Collabora | Faible | Élevé | Tests avec la dernière version avant déploiement |
| Problèmes de performance avec Solid Queue | Moyenne | Moyen | Monitoring des queues, scaling horizontal |
| Bugs de concurrence non détectés | Moyenne | Élevé | Tests de stress, monitoring des locks |
| Problèmes de cache incohérent | Élevée | Moyen | Stratégie de cache multi-niveaux avec fallback |

### Risques Organisationnels

| Risque | Probabilité | Impact | Atténuation |
|--------|-------------|--------|-------------|
| Retard sur une tâche critique | Moyenne | Élevé | Priorisation stricte, buffer de temps dans les sprints |
| Absence de développeurs | Moyenne | Moyen | Documentation complète, knowledge sharing |
| Changement des priorités métier | Élevée | Moyen | Revues régulières avec les stakeholders |
| Problèmes de déploiement | Moyenne | Élevé | Pipeline CI/CD robuste, tests automatiques |

### Risques Externes

| Risque | Probabilité | Impact | Atténuation |
|--------|-------------|--------|-------------|
| Problèmes avec Collabora Online | Faible | Élevé | Support technique, fallback sur téléchargement |
| Changement de l'API WOPI | Faible | Élevé | Abstraction du client WOPI, tests de compatibilité |
| Problèmes d'infrastructure | Faible | Élevé | Monitoring proactif, backup des services |

---

## 📈 Indicateurs de Succès

### KPI Techniques

| Métrique | Cible Sprint 1 | Cible Sprint 2 | Cible Sprint 3 |
|----------|----------------|----------------|----------------|
| Nombre de bugs critiques | 0 | 0 | 0 |
| Temps de réponse moyen (WOPI) | < 2s | < 2s | < 1.5s |
| Requêtes N+1 détectées | 0 | 0 | 0 |
| Couverture de tests | > 90% | > 90% | > 95% |

### KPI Métier

| Métrique | Cible |
|----------|-------|
| Taux de succès des workflows | > 99% |
| Temps moyen de traitement document | < 1 jour |
| Satisfaction utilisateur (WOPI) | > 4.5/5 |
| Nombre de réclamations sécurité | 0 |

---

## 📅 Calendrier Détaillé

```
Semaine 1:
  Lundi-Vendredi: Sprint 1
  
  Lundi:    Kickoff Sprint 1 + Tâche 1.1 (Jour 1/2)
  Mardi:    Tâche 1.1 (Jour 2/2) + Tâche 1.3
  Mercredi: Tâche 1.2 (Jour 1/3)
  Jeudi:    Tâche 1.2 (Jour 2/3)
  Vendredi: Tâche 1.2 (Jour 3/3) + Revue Sprint

Semaine 2:
  Lundi:    Tests Sprint 1 + Préparation Sprint 2
  Mardi:    Déploiement Sprint 1 + Kickoff Sprint 2
  Mercredi: Tâche 2.1 (Jour 1/4)
  Jeudi:    Tâche 2.1 (Jour 2/4)
  Vendredi: Tâche 2.1 (Jour 3/4)

Semaine 3:
  Lundi:    Tâche 2.1 (Jour 4/4) + Tâche 2.2 (Jour 1/3)
  Mardi:    Tâche 2.2 (Jour 2/3)
  Mercredi: Tâche 2.2 (Jour 3/3) + Tâche 2.3 (Jour 1/3)
  Jeudi:    Tâche 2.3 (Jour 2/3)
  Vendredi: Tâche 2.3 (Jour 3/3) + Revue Sprint

Semaine 4:
  Lundi:    Tests Sprint 2 + Préparation Sprint 3
  Mardi:    Déploiement Sprint 2 + Kickoff Sprint 3
  Mercredi: Tâche 3.1 (Jour 1/2)
  Jeudi:    Tâche 3.1 (Jour 2/2) + Tâche 3.2 (Jour 1/3)
  Vendredi: Tâche 3.2 (Jour 2/3)

Semaine 5:
  Lundi:    Tâche 3.2 (Jour 3/3) + Tâche 3.3 (Jour 1/3)
  Mardi:    Tâche 3.3 (Jour 2/3)
  Mercredi: Tâche 3.3 (Jour 3/3)
  Jeudi:    Tests Sprint 3
  Vendredi: Revue Sprint 3 + Rétrospective
```

---

## 🎯 Conclusion

Cette roadmap fournit un **plan d'action clair** pour aborder les complexités identifiées dans DocumentFlow. Elle est conçue pour :

1. **Stabiliser** l'application rapidement (Sprint 1)
2. **Améliorer** l'expérience utilisateur (Sprint 2)
3. **Optimiser** les performances (Sprint 3)
4. **Préparer** l'avenir (Backlog)

**Recommandations :**

- ✅ **Commencer par le Sprint 1** - Les problèmes de sécurité et stabilité sont critiques
- ✅ **Allouer du temps pour les tests** - Chaque sprint inclut des tests dédiés
- ✅ **Impliquer les stakeholders** - Revues régulières avec l'équipe métier
- ✅ **Monitorer les progrès** - Utiliser les KPI définis pour suivre l'avancement
- ✅ **Documenter les changements** - Mettre à jour la documentation technique

**Prochaines étapes:**
1. Valider la roadmap avec l'équipe
2. Affiner les estimations d'effort
3. Préparer les tickets détaillés pour le Sprint 1
4. Configurer l'environnement de test
5. Commencer le développement du Sprint 1

---

*Document généré par Mistral Vibe - 31 juillet 2026*  
*Roadmap technique détaillée pour DocumentFlow*
