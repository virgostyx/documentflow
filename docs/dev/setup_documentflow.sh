#!/bin/bash
#
# DocumentFlow - Script d'Installation Automatisé
# Rails 8 + Solid Queue + Turbo + Stimulus + TailwindCSS
#

set -e

echo "=========================================="
echo "DocumentFlow - Setup Rails 8"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_NAME="documentflow"

# Vérifier Ruby
echo -e "${BLUE}Étape 1: Vérification de Ruby...${NC}"
if command -v ruby &> /dev/null; then
    RUBY_VERSION=$(ruby --version | awk '{print $2}')
    echo -e "${GREEN}✓ Ruby $RUBY_VERSION installé${NC}\n"
else
    echo -e "${YELLOW}⚠ Ruby non trouvé. Installez Ruby 3.2+ et relancez ce script.${NC}"
    exit 1
fi

# Vérifier Rails
echo -e "${BLUE}Étape 2: Vérification de Rails...${NC}"
if command -v rails &> /dev/null; then
    RAILS_VERSION=$(rails --version | awk '{print $2}')
    echo -e "${GREEN}✓ Rails $RAILS_VERSION installé${NC}\n"
else
    echo -e "${YELLOW}Installation de Rails 8...${NC}"
    gem install rails --pre
    echo -e "${GREEN}✓ Rails 8 installé${NC}\n"
fi

# Vérifier PostgreSQL
echo -e "${BLUE}Étape 3: Vérification de PostgreSQL...${NC}"
if command -v psql &> /dev/null; then
    POSTGRES_VERSION=$(psql --version | awk '{print $3}')
    echo -e "${GREEN}✓ PostgreSQL $POSTGRES_VERSION installé${NC}\n"
else
    echo -e "${YELLOW}⚠ PostgreSQL non trouvé. Installez-le et relancez ce script.${NC}"
    exit 1
fi

# Créer l'application Rails
echo -e "${BLUE}Étape 4: Création de l'application Rails...${NC}"
rails new $APP_NAME \
  --database=postgresql \
  --css=tailwind \
  --javascript=importmap \
  --skip-test \
  --skip-jbuilder

cd $APP_NAME
echo -e "${GREEN}✓ Application créée${NC}\n"

# Ajouter les gems au Gemfile
echo -e "${BLUE}Étape 5: Configuration du Gemfile...${NC}"
cat >> Gemfile << 'GEMFILE_APPEND'

# DocumentFlow specific gems
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"
gem "devise"
gem "pundit"
gem "aasm"
gem "prawn"
gem "prawn-table"
gem "pg_search"
gem "kaminari"
gem "view_component"
gem "mission_control-jobs"

group :development, :test do
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
end

group :development do
  gem "annotate"
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "letter_opener"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
end
GEMFILE_APPEND

echo -e "${GREEN}✓ Gemfile configuré${NC}\n"

# Installer les gems
echo -e "${BLUE}Étape 6: Installation des gems...${NC}"
bundle install
echo -e "${GREEN}✓ Gems installées${NC}\n"

# Créer la base de données
echo -e "${BLUE}Étape 7: Création de la base de données...${NC}"
rails db:create
echo -e "${GREEN}✓ Base de données créée${NC}\n"

# Installer Devise
echo -e "${BLUE}Étape 8: Installation de Devise...${NC}"
rails generate devise:install
rails generate devise User
echo -e "${GREEN}✓ Devise installé${NC}\n"

# Ajouter le rôle à User
echo -e "${BLUE}Étape 9: Configuration du modèle User...${NC}"
rails generate migration AddRoleToUsers role:string
echo -e "${GREEN}✓ Migration role ajoutée${NC}\n"

# Installer RSpec
echo -e "${BLUE}Étape 10: Installation de RSpec...${NC}"
rails generate rspec:install
mkdir -p spec/factories spec/support
echo -e "${GREEN}✓ RSpec installé${NC}\n"

# Installer ViewComponent
echo -e "${BLUE}Étape 11: Installation de ViewComponent...${NC}"
rails generate view_component:install
echo -e "${GREEN}✓ ViewComponent installé${NC}\n"

# Configuration Solid Queue
echo -e "${BLUE}Étape 12: Configuration de Solid Queue...${NC}"
mkdir -p config
cat > config/queue.yml << 'QUEUE_EOF'
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
QUEUE_EOF

cat > config/recurring.yml << 'RECURRING_EOF'
daily_reminders:
  class: DailyRemindersJob
  schedule: every day at 9am
  
cleanup_expired_links:
  class: CleanupExpiredLinksJob
  schedule: every day at 2am
RECURRING_EOF

echo -e "${GREEN}✓ Solid Queue configuré${NC}\n"

# Configuration TailwindCSS personnalisée
echo -e "${BLUE}Étape 13: Configuration TailwindCSS...${NC}"
cat >> app/assets/stylesheets/application.tailwind.css << 'TAILWIND_EOF'

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
TAILWIND_EOF

echo -e "${GREEN}✓ TailwindCSS configuré${NC}\n"

# Ajouter Sortable.js pour le workflow builder
echo -e "${BLUE}Étape 14: Configuration Importmap...${NC}"
bin/importmap pin sortablejs
echo -e "${GREEN}✓ Sortable.js ajouté${NC}\n"

# Exécuter les migrations
echo -e "${BLUE}Étape 15: Exécution des migrations...${NC}"
rails db:migrate
echo -e "${GREEN}✓ Migrations exécutées${NC}\n"

# Créer le fichier README personnalisé
echo -e "${BLUE}Étape 16: Création de la documentation...${NC}"
cat > README.md << 'README_EOF'
# DocumentFlow

Système de gestion de flux documentaire avec Rails 8.

## Stack Technique

- **Framework:** Rails 8.0
- **Ruby:** 3.2+
- **Base de données:** PostgreSQL 15+
- **Jobs:** Solid Queue (sans Redis)
- **Frontend:** Turbo + Stimulus + TailwindCSS
- **Components:** ViewComponent
- **Tests:** RSpec

## Installation

```bash
bundle install
rails db:create db:migrate
```

## Démarrage

```bash
# Terminal 1 - Rails server
bin/rails server

# Terminal 2 - Solid Queue
bin/rails solid_queue:start

# Terminal 3 - TailwindCSS watch
bin/rails tailwindcss:watch
```

## Accès

- Application: http://localhost:3000
- Mission Control Jobs: http://localhost:3000/jobs

## Tests

```bash
bundle exec rspec
```

## Déploiement

Le projet utilise Kamal pour le déploiement:

```bash
kamal setup    # Premier déploiement
kamal deploy   # Déploiements suivants
```
README_EOF

echo -e "${GREEN}✓ README créé${NC}\n"

# Initialiser Git
echo -e "${BLUE}Étape 17: Initialisation Git...${NC}"
git init
git add .
git commit -m "Initial commit - DocumentFlow Rails 8"
echo -e "${GREEN}✓ Git initialisé${NC}\n"

# Résumé final
echo ""
echo "=========================================="
echo -e "${GREEN}✓ Installation terminée!${NC}"
echo "=========================================="
echo ""
echo "Prochaines étapes:"
echo ""
echo "1. Démarrer le serveur Rails:"
echo "   cd $APP_NAME"
echo "   bin/rails server"
echo ""
echo "2. Dans un autre terminal, démarrer Solid Queue:"
echo "   bin/rails solid_queue:start"
echo ""
echo "3. Dans un troisième terminal, démarrer TailwindCSS:"
echo "   bin/rails tailwindcss:watch"
echo ""
echo "4. Accéder à l'application:"
echo "   http://localhost:3000"
echo ""
echo "5. Ouvrir dans RubyMine:"
echo "   rubymine $APP_NAME"
echo ""
echo -e "${GREEN}Bon développement! 🚀${NC}"
echo ""
