# Complexité 3: Numérotation des Documents
**Date:** 31 juillet 2026  
**Version:** 1.0  
**Parent:** [COMPLEXITES_Et_DEFIS_2026-07-31.md](../COMPLEXITES_Et_DEFIS_2026-07-31.md)

---

## 📋 Table des Matières

1. [Problématique Générale](#-problématique-générale)
2. [Modèles et Code Impliqués](#-modèles-et-code-impliqués)
3. [Scénarios Problématiques Détailés](#-scénarios-problématiques-détaillés)
4. [Solutions Proposées](#-solutions-proposées)
5. [Code d'Implémentation](#-code-dimplémentation)
6. [Tests Recommandés](#-tests-recommandés)
7. [Ressources et Références](#-ressources-et-références)

---

## 🎯 Problématique Générale

La **numérotation des documents** est critique pour DocumentFlow. Chaque document doit avoir un **numéro unique** qui permet de :
- **Identifier** le document de manière univoque
- **Retrouver** le document rapidement
- **Organiser** les documents (par année, département, entité)
- **Garantir** l'intégrité des données

### 🎯 Complexités Identifiées

| Défis | Description | Impact Potentiel | Priorité |
|-------|-------------|------------------|----------|
| **Concurrency** | Plusieurs documents signés simultanément | Numéros dupliqués | ⭐⭐⭐⭐ |
| **Année de référence** | Date du document vs date de signature | Incohérence dans les rapports | ⭐⭐ |
| **Changement de département** | Document déplacé avant signature | Numéro ne correspond pas au département | ⭐⭐ |
| **Rollback de transaction** | Erreur après assignation du numéro | Numéro "consommé" mais document non signé | ⭐⭐⭐⭐ |
| **Migration de format** | Changer le format des numéros | Migration complexe des données | ⭐ |

### 📊 Format des Numéros

**Format actuel :**
- **Outgoing (avant signature):** `PROV-{id}` (ex: `PROV-123`)
- **Incoming:** `{prefix}({year}){sequence:04d}` (ex: `DOC(2026)0001`)
- **Outgoing (après signature):** `{prefix}({year}){sequence:04d}` (ex: `DOC(2026)0042`)

**Exemples:**
```
DOC(2026)0001  # Premier document du département DOC en 2026
LET(2026)0042  # 42ème document du département LET en 2026
PROV-123       # Document outgoing non encore signé
```

### 📊 Hiérarchie de Numérotation

```
Entity (prefix: "ENT")
└── Department (prefix: "DOC" ou "LET")
    └── Document
        ├── reference_number: "DOC(2026)0001" (incoming ou outgoing signé)
        └── temporary_number: "PROV-123" (outgoing non signé)
```

---

## 🏗️ Modèles et Code Impliqués

### Modèle Document (Numérotation)
```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # ...
  
  # Numérotation pour incoming (immédiate)
  before_validation :generate_reference_number, on: :create, if: :incoming?
  
  # Numéro temporaire pour outgoing
  after_create :assign_temporary_number, unless: :incoming?
  
  # Numéro définitif pour outgoing à la signature
  event :sign do
    transitions from: :in_progress, to: :signed, 
               after: [ :freeze_document, :assign_reference_number ]
  end

  # Méthode pour générer le numéro de référence
  def generate_reference_number
    return if reference_number.present?
    return unless entity && department

    year = document_date&.year || Date.current.year
    self.reference_number = next_reference_number(year: year)
  end

  # Méthode pour assigner le numéro définitif
  def assign_reference_number
    return if reference_number.present?
    return unless entity && department

    department.with_lock do
      update_column(:reference_number, next_reference_number(year: Date.current.year))
    end
  end

  # Trouve le prochain numéro disponible
  def next_reference_number(year:)
    prefix = department.prefix.presence || entity.prefix
    last = department.documents.where("reference_number LIKE ?", "#{prefix}(#{year})%").maximum(:reference_number)
    reference = last ? ReferenceNumber.parse(last).next : ReferenceNumber.first_for(prefix: prefix, year: year)
    reference.to_s
  end
  
  # Numéro temporaire
  def assign_temporary_number
    update_column(:temporary_number, "PROV-#{id}")
  end
  
  # Méthode pour afficher le numéro
  def display_number
    reference_number.presence || temporary_number
  end
end
```

### Value Object: ReferenceNumber
```ruby
# app/value_objects/reference_number.rb
class ReferenceNumber
  attr_reader :prefix, :year, :sequence

  def initialize(prefix, year, sequence)
    @prefix = prefix
    @year = year
    @sequence = sequence
  end

  def self.parse(number)
    # Ex: "DOC(2026)0042" → {prefix: "DOC", year: 2026, sequence: 42}
    match = number.match(/^([A-Z0-9]+)\((\d{4})\)(\d+)$/)
    new(match[1], match[2].to_i, match[3].to_i)
  end

  def self.first_for(prefix:, year:)
    new(prefix, year, 1)
  end

  def next
    ReferenceNumber.new(prefix, year, sequence + 1)
  end

  def to_s
    "#{prefix}(#{year})#{sequence.to_s.rjust(4, '0')}"
  end
end
```

### Modèle Department
```ruby
# app/models/department.rb
class Department < ApplicationRecord
  belongs_to :entity
  
  validates :prefix, presence: true,
                    length: { maximum: 8 },
                    format: { with: /\A[A-Z0-9]+\z/, message: "must contain only uppercase letters and digits" },
                    uniqueness: { scope: :entity_id }
end
```

### Modèle Entity
```ruby
# app/models/entity.rb
class Entity < ApplicationRecord
  validates :prefix, presence: true,
                    length: { maximum: 8 },
                    format: { with: /\A[A-Z0-9]+\z/, message: "must contain only uppercase letters and digits" },
                    uniqueness: true
end
```

---

## ⚠️ Scénarios Problématiques Détailés

### 🎯 Cas 1: Concurrence sur la Signature

**Scénario :**
Deux utilisateurs **signent deux documents simultanément** dans le **même département** au **même moment**.

**Problème :**
- Les deux appellent `next_reference_number` **en même temps**
- Sans verrou, les deux pourraient **obtenir le même numéro** !

**Code Actuel (Bon, mais perfectible) :**
```ruby
def assign_reference_number
  return if reference_number.present?
  return unless entity && department

  department.with_lock do # ← Verrou sur le département
    update_column(:reference_number, next_reference_number(year: Date.current.year))
  end
end
```

**Comment ça marche :**
1. `with_lock` → **SELECT ... FOR UPDATE** sur `departments`
2. Le premier processus **bloque** le second
3. Le second attend que le premier ait fini
4. Chaque document obtient un **numéro unique**

**Risques résiduels :**
- ⚠️ **Timeout de verrou** : Si un processus plante, le verrou peut rester bloqué
- ⚠️ **Performance** : Les signatures deviennent **sérialisées** par département
- ⚠️ **Deadlocks** : Si plusieurs processus tentent de verrouiller différents départements

---

### 🎯 Cas 2: Année de Référence Incohérente

**Scénario :**
- Un document est créé le **31 décembre 2025** avec `document_date = 2025-12-31`
- Il est signé le **1er janvier 2026**

**Problème :**
- `next_reference_number` utilise **`Date.current.year`** (2026)
- Mais le document a une date de **2025**
- **Incohérence** : Numéro de 2026 pour un document de 2025

**Code Problématique :**
```ruby
def assign_reference_number
  # ...
  update_column(:reference_number, next_reference_number(year: Date.current.year)) # ← Toujours l'année courante
end
```

**Risques :**
- ❌ **Confusion utilisateur** : Pourquoi ce document a un numéro 2026 ?
- ❌ **Reporting** : Difficile de regrouper les documents par année de référence
- ❌ **Audit** : Le numéro ne reflète pas la date réelle du document

---

### 🎯 Cas 3: Changement de Département

**Scénario :**
- Un document est créé dans le **Département A** (prefix `DOC`)
- Avant signature, il est **déplacé vers le Département B** (prefix `LET`)
- Le document est signé

**Problème :**
- À la signature, `next_reference_number` utilise **Département B**
- Mais le document a été créé avec l'intention d'avoir un numéro **Département A**
- **Incohérence** : Numéro ne correspond pas au département initial

**Risques :**
- ❌ **Données incohérentes** : Difficile de retrouver un document par son numéro
- ❌ **Audit** : Le numéro ne reflète pas l'historique du document
- ❌ **Reporting** : Impossible de filtrer correctement par département

---

### 🎯 Cas 4: Rollback de Transaction

**Scénario :**
La signature déclenche :
1. `assign_reference_number` → **numéro assigné**
2. `freeze_document` → **document gelé**
3. Une **erreur** survient (ex: notification échoue)

**Problème :**
- La transaction est **annulée** (rollback)
- Mais `update_column` **contourne les callbacks** → **le numéro reste assigné** !
- Le document reste **non signé** mais avec un **numéro définitif**

**Code Problématique :**
```ruby
def assign_reference_number
  return if reference_number.present?
  return unless entity && department

  department.with_lock do
    update_column(:reference_number, next_reference_number(year: Date.current.year)) # ← Contourne les callbacks !
  end
end
```

**Risques :**
- ❌ **Données corrompues** : Document avec numéro définitif mais statut `in_progress`
- ❌ **Numéros manquants** : Le numéro est "consommé" mais pas utilisé
- ❌ **Difficulté de récupération** : Impossible de réassigner ce numéro

---

### 🎯 Cas 5: Migration de Format

**Scénario :**
On veut **changer le format** des numéros de `DOC(2026)0001` à `DOC-2026-0001`.

**Problème :**
- Tous les numéros existants sont **stockés en texte** dans la DB
- **Impossible de parser** les anciens numéros avec le nouveau format
- **Migration complexe** : Il faut mettre à jour **tous les documents**

**Risques :**
- ❌ **Downtime** : Migration longue sur une grosse DB
- ❌ **Erreurs** : Format incohérent pendant la migration
- ❌ **Rollback difficile** : Si la migration échoue, comment revenir en arrière ?

---

## 💡 Solutions Proposées

| Problème | Solution | Complexité | Impact |
|----------|----------|------------|--------|
| Concurrence | Verrou optimiste (`lock_version`) | ⭐⭐ | Moyen |
| Année de référence | Utiliser `document_date.year` | ⭐ | Haut |
| Changement de département | Bloquer les changements | ⭐ | Moyen |
| Rollback | Ne pas utiliser `update_column` | ⭐ | Haut |
| Migration | Champ `reference_number_format` | ⭐⭐ | Faible |

---

## 🔧 Code d'Implémentation

### ✅ Solution 1: Utiliser document_date.year pour la Référence

**Fichier :** `app/models/document.rb`
```ruby
def assign_reference_number
  return if reference_number.present?
  return unless entity && department

  # Utiliser l'année du document, pas l'année courante
  year = document_date.year
  
  department.with_lock do
    # Ne pas utiliser update_column pour permettre le rollback
    self.reference_number = next_reference_number(year: year)
    save!(validate: false) # Sauvegarde avec la transaction AASM
  end
end

def generate_reference_number
  return if reference_number.present?
  return unless entity && department

  # Utiliser l'année du document pour incoming aussi
  year = document_date&.year || Date.current.year
  self.reference_number = next_reference_number(year: year)
end
```

**Avantages :**
- ✅ Cohérence entre la date du document et son numéro
- ✅ Facilite le reporting par année
- ✅ Plus intuitif pour les utilisateurs

**Inconvénients :**
- ⚠️ Peut causer des problèmes si `document_date` change après la création

---

### ✅ Solution 2: Bloquer le Changement de Département

**Fichier :** `app/models/document.rb`
```ruby
# Empêcher le changement de département après la création
before_update :prevent_department_change_after_creation

def prevent_department_change_after_creation
  if department_id_changed? && !draft?
    errors.add(:department, "cannot be changed after document creation")
    throw :abort
  end
end
```

**Fichier :** `app/models/workflow_step.rb`
```ruby
# S'assurer que les étapes appartiennent au bon département
validate :department_matches_document

def department_matches_document
  if document.present? && document.department_id != document.entity.departments.find_by(id: document.department_id)&.id
    errors.add(:base, "Workflow step department must match document department")
  end
end
```

**Avantages :**
- ✅ Évite les incohérences de numérotation
- ✅ Garantit que le numéro reflète bien le département
- ✅ Simple à implémenter

**Inconvénients :**
- ⚠️ Moins flexible (impossible de déplacer un document)

---

### ✅ Solution 3: Correction du Rollback (TRÈS IMPORTANT)

**Problème :** `update_column` contourne les callbacks et la transaction AASM.

**Fichier :** `app/models/document.rb`
```ruby
# Modifier la transition AASM pour tout faire dans un bloc
event :sign do
  transitions from: :in_progress, to: :signed do
    # Tout dans un bloc pour garantir l'atomicité
    assign_reference_number
    freeze_document
  end
end

# Et dans assign_reference_number :
def assign_reference_number
  return if reference_number.present?
  return unless entity && department

  year = document_date.year
  
  department.with_lock do
    new_number = next_reference_number(year: year)
    self.reference_number = new_number # ← Ne pas utiliser update_column !
    # La sauvegarde est faite par AASM dans la transition
  end
end
```

**Alternative : Service dédié**
```ruby
# app/services/documents/actions/assign_reference_number.rb
module Documents
  module Actions
    class AssignReferenceNumber < ApplicationAction
      expects :document
      
      executed do |ctx|
        document = ctx.document
        return ctx if document.reference_number.present?
        
        year = document.document_date.year
        
        document.department.with_lock do
          document.reference_number = document.next_reference_number(year: year)
          document.save!(validate: false)
        end
        
        ctx
      end
    end
  end
end
```

**Avantages :**
- ✅ Le numéro est assigné **dans la même transaction** que la signature
- ✅ En cas d'erreur, **tout est rollbacké** (y compris le numéro)
- ✅ Plus robuste et maintenable

---

### ✅ Solution 4: Verrou Optimiste (Alternative)

**Idée :** Utiliser `lock_version` au lieu de `with_lock` pour éviter les blocages.

**Migration :**
```ruby
# db/migrate/[timestamp]_add_lock_version_to_department.rb
class AddLockVersionToDepartment < ActiveRecord::Migration[8.1]
  def change
    add_column :departments, :lock_version, :integer, default: 0, null: false
  end
end
```

**Modèle :**
```ruby
# app/models/department.rb
class Department < ApplicationRecord
  # Verrou optimiste déjà inclus par Rails si lock_version existe
end
```

**Fichier :** `app/models/document.rb`
```ruby
def assign_reference_number
  return if reference_number.present?
  return unless entity && department

  year = document_date.year
  
  # Verrou optimiste (pas besoin de with_lock)
  new_number = next_reference_number(year: year)
  
  # Rails gérera le verrou optimiste
  self.reference_number = new_number
  save!(validate: false)
rescue ActiveRecord::StaleObjectError
  # Si conflit, réessayer
  retry if retries < 3
  raise
end
```

**Avantages :**
- ✅ Pas de blocage de la table (meilleure concurrence)
- ✅ Moins de risques de deadlock
- ✅ Plus scalable

**Inconvénients :**
- ⚠️ Plus complexe à implémenter
- ⚠️ Nécessite de gérer les retries

---

### ✅ Solution 5: Migration de Format (Backward Compatible)

**Idée :** Stocker le **format** du numéro séparément pour permettre une migration progressive.

**Migration :**
```ruby
# db/migrate/[timestamp]_add_reference_number_format_to_entity.rb
class AddReferenceNumberFormatToEntity < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :reference_number_format, :string, default: "({year}){sequence:04d}"
  end
end
```

**Modèle Entity :**
```ruby
# app/models/entity.rb
class Entity < ApplicationRecord
  # Format par défaut : "DOC({year}){sequence:04d}" → "DOC(2026)0001"
  # Nouveau format : "{prefix}-{year}-{sequence:04d}" → "DOC-2026-0001"
end
```

**Fichier :** `app/models/document.rb`
```ruby
def next_reference_number(year:)
  prefix = department.prefix.presence || entity.prefix
  format = entity.reference_number_format || "({year}){sequence:04d}"
  last = department.documents.where("reference_number LIKE ?", "#{prefix}%#{year}%").maximum(:reference_number)
  
  if last
    last_number = ReferenceNumber.parse(last, format: format)
    new_number = last_number.next
  else
    new_number = ReferenceNumber.first_for(prefix: prefix, year: year, format: format)
  end
  
  new_number.to_s(format: format)
end
```

**Fichier :** `app/value_objects/reference_number.rb`
```ruby
class ReferenceNumber
  attr_reader :prefix, :year, :sequence, :format

  # ...
  
  def self.parse(number, format: "({year}){sequence:04d}")
    # Adapter le parsing en fonction du format
    case format
    when "({year}){sequence:04d}"
      match = number.match(/^([A-Z0-9]+)\((\d{4})\)(\d+)$/)
      new(match[1], match[2].to_i, match[3].to_i, format)
    when "{prefix}-{year}-{sequence:04d}"
      match = number.match(/^([A-Z0-9]+)-(\d{4})-(\d+)$/)
      new(match[1], match[2].to_i, match[3].to_i, format)
    else
      raise "Unknown format: #{format}"
    end
  end

  def to_s(format: @format)
    case format
    when "({year}){sequence:04d}"
      "#{prefix}(#{year})#{sequence.to_s.rjust(4, '0')}"
    when "{prefix}-{year}-{sequence:04d}"
      "#{prefix}-#{year}-#{sequence.to_s.rjust(4, '0')}"
    else
      raise "Unknown format: #{format}"
    end
  end
end
```

**Avantages :**
- ✅ Migration **sans downtime**
- ✅ Backward compatible
- ✅ Facile à tester
- ✅ Permet de changer de format à l'avenir

---

## 🧪 Tests Recommandés

### Tests Unitaires (RSpec)

#### Test de la Génération des Numéros
```ruby
# spec/models/document_spec.rb
RSpec.describe Document do
  let(:entity) { create(:entity, prefix: "DOC") }
  let(:department) { create(:department, entity: entity, prefix: "LET") }

  describe "reference number generation" do
    context "for incoming documents" do
      it "generates reference number immediately" do
        document = create(:document, 
          entity: entity, 
          department: department,
          direction: "incoming",
          document_date: Date.new(2026, 1, 15)
        )
        expect(document.reference_number).to eq("LET(2026)0001")
      end
      
      it "uses document_date year for reference number" do
        document = create(:document, 
          entity: entity, 
          department: department,
          direction: "incoming",
          document_date: Date.new(2025, 12, 31)
        )
        expect(document.reference_number).to eq("LET(2025)0001")
      end
    end

    context "for outgoing documents" do
      it "generates temporary number on creation" do
        document = create(:document, 
          entity: entity, 
          department: department,
          direction: "outgoing",
          document_date: Date.new(2026, 1, 15)
        )
        expect(document.temporary_number).to eq("PROV-#{document.id}")
        expect(document.reference_number).to be_nil
      end

      it "generates definitive reference number on sign" do
        document = create(:document, 
          entity: entity, 
          department: department,
          direction: "outgoing",
          status: :in_progress,
          document_date: Date.new(2026, 1, 15)
        )
        create(:workflow_step, document: document, role: "SIGN")
        
        document.sign!
        expect(document.reference_number).to eq("LET(2026)0001")
        expect(document.display_number).to eq("LET(2026)0001")
      end
      
      it "uses document_date year for reference number on sign" do
        document = create(:document, 
          entity: entity, 
          department: department,
          direction: "outgoing",
          status: :in_progress,
          document_date: Date.new(2025, 12, 31)
        )
        create(:workflow_step, document: document, role: "SIGN")
        
        document.sign!
        expect(document.reference_number).to eq("LET(2025)0001")
      end
    end
  end

  describe "display_number" do
    it "returns temporary_number for unsigned outgoing documents" do
      document = create(:document, 
        entity: entity, 
        department: department,
        direction: "outgoing",
        temporary_number: "PROV-123"
      )
      expect(document.display_number).to eq("PROV-123")
    end

    it "returns reference_number for signed documents" do
      document = create(:document, 
        entity: entity, 
        department: department,
        reference_number: "LET(2026)0042"
      )
      expect(document.display_number).to eq("LET(2026)0042")
    end
  end
end
```

#### Test du ReferenceNumber
```ruby
# spec/value_objects/reference_number_spec.rb
RSpec.describe ReferenceNumber do
  describe ".parse" do
    it "parses standard format" do
      number = described_class.parse("DOC(2026)0042")
      expect(number.prefix).to eq("DOC")
      expect(number.year).to eq(2026)
      expect(number.sequence).to eq(42)
    end

    it "parses new format" do
      number = described_class.parse("DOC-2026-0042", format: "{prefix}-{year}-{sequence:04d}")
      expect(number.prefix).to eq("DOC")
      expect(number.year).to eq(2026)
      expect(number.sequence).to eq(42)
    end

    it "raises error for invalid format" do
      expect {
        described_class.parse("INVALID")
      }.to raise_error(/Unknown format/)
    end
  end

  describe "#to_s" do
    it "formats standard style" do
      number = described_class.new("DOC", 2026, 42)
      expect(number.to_s).to eq("DOC(2026)0042")
    end

    it "formats new style" do
      number = described_class.new("DOC", 2026, 42)
      expect(number.to_s(format: "{prefix}-{year}-{sequence:04d}")).to eq("DOC-2026-0042")
    end
  end

  describe "#next" do
    it "increments sequence" do
      number = described_class.new("DOC", 2026, 42)
      next_number = number.next
      expect(next_number.sequence).to eq(43)
      expect(next_number.to_s).to eq("DOC(2026)0043")
    end

    it "preserves year and prefix" do
      number = described_class.new("LET", 2025, 99)
      next_number = number.next
      expect(next_number.prefix).to eq("LET")
      expect(next_number.year).to eq(2025)
      expect(next_number.sequence).to eq(100)
    end
  end

  describe ".first_for" do
    it "returns first number for prefix and year" do
      number = described_class.first_for(prefix: "DOC", year: 2026)
      expect(number.to_s).to eq("DOC(2026)0001")
    end
  end
end
```

#### Test de la Prévention du Changement de Département
```ruby
# spec/models/document_spec.rb
RSpec.describe Document do
  let(:entity) { create(:entity) }
  let(:department1) { create(:department, entity: entity, prefix: "DOC") }
  let(:department2) { create(:department, entity: entity, prefix: "LET") }

  describe "department change prevention" do
    it "allows department change in draft status" do
      document = create(:document, entity: entity, department: department1, status: :draft)
      expect { document.update!(department: department2) }.to change(document, :department)
    end

    it "prevents department change after draft" do
      document = create(:document, entity: entity, department: department1, status: :in_progress)
      expect { document.update!(department: department2) }.not_to change(document, :department)
      expect(document.errors[:department]).to include("cannot be changed after document creation")
    end

    it "prevents department change for signed documents" do
      document = create(:document, entity: entity, department: department1, status: :signed)
      expect { document.update!(department: department2) }.not_to change(document, :department)
    end

    it "prevents department change for finalized documents" do
      document = create(:document, entity: entity, department: department1, status: :finalized)
      expect { document.update!(department: department2) }.not_to change(document, :department)
    end
  end
end
```

#### Test du Rollback
```ruby
# spec/models/document_spec.rb
RSpec.describe Document do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity, prefix: "DOC") }

  describe "reference number assignment on sign" do
    let(:document) { create(:document, entity: entity, department: department, status: :in_progress) }

    before do
      create(:workflow_step, document: document, role: "SIGN")
    end

    it "assigns reference number within transaction" do
      expect(document.reference_number).to be_nil
      
      expect {
        document.sign!
      }.to change(document, :status).from("in_progress").to("signed")
      
      expect(document.reload.reference_number).to eq("DOC(2026)0001")
    end

    it "rolls back reference number on failure" do
      # Simuler une erreur après assign_reference_number
      allow(document).to receive(:freeze_document).and_raise("Simulated error")
      
      expect {
        document.sign!
      }.to raise_error("Simulated error")
      
      # Le document ne doit pas être signé
      expect(document.reload.status).to eq("in_progress")
      # Le numéro ne doit pas être assigné
      expect(document.reload.reference_number).to be_nil
    end
  end
end
```

### Tests de Concurrence
```ruby
# spec/models/document_concurrency_spec.rb
RSpec.describe "Document numbering concurrency", :slow do
  let(:entity) { create(:entity, prefix: "TEST") }
  let(:department) { create(:department, entity: entity, prefix: "TST") }

  it "prevents duplicate reference numbers under concurrency" do
    # Créer 10 documents en draft
    documents = 10.times.map do |i|
      create(:document, 
        entity: entity,
        department: department,
        status: :in_progress,
        document_date: Date.new(2026, 1, 1)
      )
    end
    
    # Ajouter une étape SIGN à chaque document
    documents.each do |doc|
      create(:workflow_step, document: doc, role: "SIGN")
    end
    
    # Signer tous les documents en parallèle
    threads = documents.map do |doc|
      Thread.new { doc.sign! }
    end
    
    threads.each(&:join)
    
    # Reload et vérifier que tous les numéros sont uniques
    documents.reload.map(&:reference_number).each do |ref|
      expect(ref).to match(/^TST\(2026\)\d{4}$/)
    end
    
    # Vérifier l'unicité
    reference_numbers = documents.reload.map(&:reference_number)
    expect(reference_numbers.uniq.size).to eq(reference_numbers.size)
  end

  it "handles concurrent numbering across different departments" do
    department2 = create(:department, entity: entity, prefix: "LET")
    
    # 5 documents dans chaque département
    docs1 = 5.times.map { create(:document, entity: entity, department: department, status: :in_progress) }
    docs2 = 5.times.map { create(:document, entity: entity, department: department2, status: :in_progress) }
    
    all_docs = docs1 + docs2
    all_docs.each { |d| create(:workflow_step, document: d, role: "SIGN") }
    
    # Signer en parallèle
    threads = all_docs.map { |d| Thread.new { d.sign! } }
    threads.each(&:join)
    
    # Vérifier les formats
    docs1.reload.each do |d|
      expect(d.reference_number).to match(/^TST\(2026\)\d{4}$/)
    end
    
    docs2.reload.each do |d|
      expect(d.reference_number).to match(/^LET\(2026\)\d{4}$/)
    end
  end
end
```

---

## 🎯 Résumé des Actions Clés

| Action | Fichier | Description | Priorité |
|--------|---------|-------------|----------|
| `assign_reference_number` | `app/models/document.rb` | Assigne le numéro définitif | 🔴 |
| `next_reference_number` | `app/models/document.rb` | Trouve le prochain numéro | 🔴 |
| `display_number` | `app/models/document.rb` | Affiche le bon numéro | 🟡 |
| `prevent_department_change_after_creation` | `app/models/document.rb` | Empêche le changement de département | 🟡 |
| Verrou DB | `department.with_lock` | Garantit l'unicité | 🔴 |
| `ReferenceNumber` | `app/value_objects/reference_number.rb` | Parse et formate les numéros | 🔴 |

---

## 📚 Ressources et Références

### Documentation Connexe
- [ActiveRecord Locking](https://guides.rubyonrails.org/active_record_querying.html#locking-records-for-update)
- [Optimistic vs Pessimistic Locking](https://api.rubyonrails.org/classes/ActiveRecord/Locking.html)
- [Database Transactions in Rails](https://guides.rubyonrails.org/active_record_transaction.html)
- [Value Objects in Ruby](https://martinfowler.com/bliki/ValueObject.html)

### Bonnes Pratiques
- Toujours utiliser des **verrous** pour les opérations qui doivent être atomiques
- Préférer les **verrous pessimistes** (`with_lock`) pour les opérations critiques
- Utiliser les **verrous optimistes** (`lock_version`) pour les opérations moins critiques
- **Ne jamais** utiliser `update_column` dans une transition qui peut échouer
- Toujours **tester la concurrence** avec des tests multi-thread

---

## 🔗 Voir Aussi

- [Complexité 1: Workflows](../01_workflows.md)
- [Complexité 2: Données Polymorphiques](../02_polymorphic_associations.md)
- [Complexité 4: Intégration WOPI](../04_wopi_integration.md)
- [Complexité 5: Notifications Temps Réel](../05_real_time_notifications.md)

---

**Prochaine étape :** [Complexité 4: Intégration WOPI](../04_wopi_integration.md) 🚀
