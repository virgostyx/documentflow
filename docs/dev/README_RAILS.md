# DOCUMENTFLOW - PROJET RAILS 8
## Guide Complet de Démarrage

**Framework:** Ruby on Rails 8.0  
**Date:** 9 Mars 2026  
**Client:** virgostyx

---

## 🎯 VUE D'ENSEMBLE

**DocumentFlow** est un système de gestion de flux documentaire développé avec **Rails 8**, utilisant les dernières technologies modernes:

- ✅ **Solid Queue** - Jobs sans Redis
- ✅ **Turbo + Stimulus** - SPA moderne sans complexité
- ✅ **ViewComponent** - Composants réutilisables
- ✅ **TailwindCSS** - Design utility-first
- ✅ **Kamal 2** - Déploiement simplifié

---

## 📚 DOCUMENTATION DISPONIBLE

### Documents Rails 8 (Nouveaux)

| Fichier | Description | Taille |
|---------|-------------|--------|
| `00_Concept_Note.md` | **Note de concept complète Rails 8** | 17KB |
| `01_Setup_Guide.md` | **Guide d'installation détaillé** | 21KB |
| `02_Quick_Reference.md` | **Référence rapide des commandes** | 10KB |
| `setup_documentflow.sh` | **Script d'installation automatisé** | 7.5KB |

### Documents Django (Anciens - Pour Référence)

Les documents Django originaux sont toujours disponibles pour consultation:
- Spécifications techniques complètes
- Architecture de base de données
- Logique métier documentée
- Tout est transposable en Rails

---

## 🚀 DÉMARRAGE RAPIDE

### Option 1: Installation Automatique (Recommandé)

```bash
# Exécuter le script d'installation
bash setup_documentflow.sh
```

**Ce script fait automatiquement:**
1. ✅ Vérifie Ruby, Rails, PostgreSQL
2. ✅ Crée l'application Rails 8
3. ✅ Configure toutes les gems nécessaires
4. ✅ Installe Devise, RSpec, ViewComponent
5. ✅ Configure Solid Queue
6. ✅ Configure TailwindCSS
7. ✅ Crée la structure de base
8. ✅ Initialise Git

**Après le script:**
```bash
cd documentflow

# Terminal 1 - Serveur Rails
bin/rails server

# Terminal 2 - Solid Queue
bin/rails solid_queue:start

# Terminal 3 - TailwindCSS
bin/rails tailwindcss:watch
```

### Option 2: Installation Manuelle

Suivre le guide détaillé dans `01_Setup_Guide.md`

---

## 📖 GUIDES PAR BESOIN

### Pour Démarrer le Projet

1. **Lire d'abord:** `00_Concept_Note.md`
   - Comprendre l'architecture Rails 8
   - Stack technique complète
   - Modèles de données
   - Workflow et business logic

2. **Installer:** `setup_documentflow.sh` OU `01_Setup_Guide.md`
   - Installation automatique (script)
   - Installation manuelle pas-à-pas

3. **Référence quotidienne:** `02_Quick_Reference.md`
   - Commandes fréquentes
   - Générateurs Rails
   - Solid Queue
   - ViewComponents
   - Stimulus
   - Tests RSpec

### Pour le Développement avec RubyMine

**Configuration RubyMine:**
1. File → Open → Sélectionner `documentflow/`
2. Trust Project
3. RubyMine détecte automatiquement:
   - Ruby SDK
   - Gemfile
   - Base de données
   - Run configurations

**Run Configurations à créer:**
- Rails Server
- Solid Queue
- RSpec

**Raccourcis utiles:**
- `Cmd+Shift+O` : Rechercher fichier
- `Cmd+O` : Rechercher classe
- `Ctrl+R` : Exécuter tests
- `Ctrl+Shift+R` : Exécuter tous les tests

### Pour le Développement avec Claude Code

```bash
# Installer Claude Code
npm install -g @anthropic-ai/claude-code

# Dans le projet
cd documentflow
claude-code

# Exemples d'utilisation
claude-code "Créer le contrôleur Documents avec CRUD"
claude-code "Implémenter WorkflowStateMachine avec AASM"
claude-code "Générer tests RSpec pour Document model"
```

---

## 🏗️ STRUCTURE DU PROJET

```
documentflow/
├── app/
│   ├── controllers/      # Contrôleurs Rails
│   ├── models/          # ActiveRecord models
│   ├── views/           # Templates ERB + Turbo
│   ├── components/      # ViewComponents
│   ├── services/        # Business logic
│   ├── jobs/            # Solid Queue jobs
│   ├── mailers/         # Action Mailer
│   └── javascript/      # Stimulus controllers
├── config/
│   ├── routes.rb
│   ├── database.yml
│   ├── queue.yml        # Solid Queue config
│   ├── recurring.yml    # Jobs récurrents
│   └── deploy.yml       # Kamal deployment
├── db/
│   ├── migrate/         # Migrations
│   └── seeds.rb
├── spec/                # Tests RSpec
│   ├── models/
│   ├── requests/
│   ├── components/
│   └── factories/
└── Gemfile
```

---

## 🔧 STACK TECHNIQUE COMPLÈTE

### Backend
- **Ruby:** 3.2.2+
- **Rails:** 8.0.0
- **Database:** PostgreSQL 17
- **Jobs:** Solid Queue (intégré Rails 8)
- **Cache:** Solid Cache
- **Auth:** Devise
- **Authorization:** Pundit
- **State Machine:** AASM
- **Search:** pg_search
- **PDF:** Prawn

### Frontend
- **Navigation:** Turbo (SPA sans JS complexe)
- **JavaScript:** Stimulus (contrôleurs légers)
- **Components:** ViewComponent
- **CSS:** TailwindCSS
- **Module System:** Importmap

### Tests
- **Framework:** RSpec
- **Factories:** Factory Bot
- **Data:** Faker
- **Matchers:** Shoulda Matchers
- **System Tests:** Capybara + Selenium

### Production
- **Server:** Puma
- **Reverse Proxy:** Nginx
- **Deployment:** Kamal 2
- **SSL:** Let's Encrypt
- **Monitoring:** Rails Error Reporting

---

## 📝 WORKFLOW DOCUMENTFLOW

### Séquence Obligatoire

```
RED → VISA(s) → SIGN → EXP
```

- **RED** (Rédacteur): Premier acteur, ne peut pas rejeter
- **VISA** (Validateur): Peut être multiple, séquentiel ou parallèle
- **SIGN** (Signataire): Signe le document
- **EXP** (Expéditeur): Dernier acteur, déclenche la finalisation

### États du Document

```
DRAFT → IN_PROGRESS → SIGNED → FINALIZED
```

### Règles Métier

1. ✅ Référence: YYYY/##### (compteur global, reset annuel)
2. ✅ RED ne peut pas rejeter (seulement modifier ou annuler)
3. ✅ Rejet retourne à l'acteur précédent
4. ✅ Acteur courant: droits de modification complets
5. ✅ Finalisation: document gelé, conversion PDF, envoi email
6. ✅ Tous les utilisateurs voient tous les documents
7. ✅ Limite fichiers: 25MB/fichier, 100MB/document

---

## 🧪 TESTS

### Exécuter les Tests

```bash
# Tous les tests
bundle exec rspec

# Un fichier
bundle exec rspec spec/models/document_spec.rb

# Une ligne spécifique
bundle exec rspec spec/models/document_spec.rb:15

# Avec coverage
COVERAGE=true bundle exec rspec
```

### Structure de Test

```ruby
RSpec.describe Document, type: :model do
  describe "validations" do
    it { should validate_presence_of(:subject) }
  end
  
  describe "associations" do
    it { should belong_to(:created_by) }
  end
  
  describe "#generate_reference_number" do
    it "generates unique numbers" do
      # Test code
    end
  end
end
```

---

## 🚢 DÉPLOIEMENT

### Avec Kamal (Recommandé)

```bash
# Initialiser
kamal init

# Configurer config/deploy.yml
# (voir 00_Concept_Note.md pour exemple complet)

# Premier déploiement
kamal setup

# Déploiements suivants
kamal deploy

# Rollback si nécessaire
kamal rollback
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
  clear:
    RAILS_ENV: production

accessories:
  postgres:
    image: postgres:17
```

---

## 📊 AVANTAGES DE RAILS 8

### vs Django (Pourquoi le Changement)

| Aspect | Rails 8 | Django |
|--------|---------|--------|
| **Structure** | Convention over Configuration | Configuration explicite |
| **Jobs** | Solid Queue (intégré, sans Redis) | Celery (Redis requis) |
| **Frontend** | Turbo + Stimulus (natif) | HTMX (3rd party) |
| **ORM** | ActiveRecord (élégant) | Django ORM (verbeux) |
| **Migrations** | Réversibles auto | Manuelles |
| **Admin** | Facile à personnaliser | Bon mais rigide |
| **Tests** | RSpec (expressif) | pytest (bon mais verbose) |
| **Déploiement** | Kamal (natif) | Gunicorn + config |

### Nouveautés Rails 8

1. **Solid Queue** - Jobs persistés en PostgreSQL, pas de Redis
2. **Solid Cache** - Cache en PostgreSQL
3. **Solid Cable** - WebSockets sans Redis
4. **Authentication** - Générateur intégré
5. **PWA** - Support natif
6. **Performance** - Optimisations majeures

---

## 🎓 PROCHAINES ÉTAPES

### Phase 1: Setup (1 jour)
- [x] Lire la documentation
- [ ] Exécuter `setup_documentflow.sh`
- [ ] Vérifier que tout fonctionne
- [ ] Se familiariser avec la structure

### Phase 2: Models (2-3 jours)
- [ ] Générer tous les models
- [ ] Ajouter validations et associations
- [ ] Implémenter state machine avec AASM
- [ ] Écrire tests models

### Phase 3: Controllers & Views (1 semaine)
- [ ] Générer contrôleurs CRUD
- [ ] Créer vues avec Turbo
- [ ] Développer ViewComponents
- [ ] Implémenter workflow builder

### Phase 4: Workflow Logic (1 semaine)
- [ ] Service WorkflowStateMachine
- [ ] Jobs de notification
- [ ] Conversion PDF
- [ ] Tests d'intégration

### Phase 5: Frontend Interactif (3-4 jours)
- [ ] Stimulus controllers
- [ ] Workflow builder drag-and-drop
- [ ] Upload de fichiers
- [ ] Recherche live

### Phase 6: Tests & Polish (3-4 jours)
- [ ] Tests RSpec complets (>80% coverage)
- [ ] Tests système avec Capybara
- [ ] Corrections bugs
- [ ] UI/UX improvements

### Phase 7: Déploiement (1 jour)
- [ ] Configuration Kamal
- [ ] Premier déploiement
- [ ] Monitoring
- [ ] Documentation production

---

## 🆘 SUPPORT

### Documentation

- **Rails Guides**: https://guides.rubyonrails.org/
- **Solid Queue**: https://github.com/basecamp/solid_queue
- **Turbo**: https://turbo.hotwired.dev/
- **Stimulus**: https://stimulus.hotwired.dev/
- **ViewComponent**: https://viewcomponent.org/
- **Kamal**: https://kamal-deploy.org/

### Communauté

- **Forum Rails**: https://discuss.rubyonrails.org/
- **Reddit**: r/rails
- **Discord**: Rails Discord Server
- **Stack Overflow**: Tag `ruby-on-rails`

### Troubleshooting

Consultez `02_Quick_Reference.md` section Troubleshooting pour:
- Serveur qui ne démarre pas
- Solid Queue qui ne fonctionne pas
- Migrations en erreur
- TailwindCSS qui ne compile pas
- Assets manquants

---

## 📞 RÉSUMÉ DES FICHIERS

### À Lire en Premier
1. **Ce fichier (README)** - Vue d'ensemble
2. **00_Concept_Note.md** - Architecture complète
3. **01_Setup_Guide.md** - Installation détaillée

### Pour Référence
- **02_Quick_Reference.md** - Commandes quotidiennes
- **setup_documentflow.sh** - Installation auto

### Ancienne Documentation Django
- Disponible pour référence (modèles, logique métier)
- Tout est transposable en Rails

---

## ✅ CHECKLIST DE DÉMARRAGE

- [ ] Ruby 3.2+ installé
- [ ] Rails 8 installé
- [ ] PostgreSQL 17+ installé et démarré
- [ ] Node.js installé (pour JavaScript)
- [ ] RubyMine configuré (optionnel)
- [ ] Documentation lue
- [ ] `setup_documentflow.sh` exécuté
- [ ] Application démarre sur localhost:3000
- [ ] Solid Queue fonctionne
- [ ] TailwindCSS compile
- [ ] Tests RSpec passent

---

## 🚀 COMMANDE DE DÉMARRAGE RAPIDE

```bash
# Installation
bash setup_documentflow.sh

# Démarrage (3 terminaux)
cd documentflow
bin/rails server                  # Terminal 1
bin/rails solid_queue:start       # Terminal 2
bin/rails tailwindcss:watch       # Terminal 3

# Accès
open http://localhost:3000
```

---

**DocumentFlow - Rails 8 - Simple, Élégant, Puissant** 🚀

**Bon développement avec Rails 8!**
