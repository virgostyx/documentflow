# DocumentFlow - Outils de Monitoring et Debug
**Date:** 31 juillet 2026  
**Version:** 1.0  
**Auteur:** Mistral Vibe  
**Public cible:** Équipe de développement, DevOps, SRE, Support Technique  

---

## 📋 Table des Matières

1. [Introduction](#-introduction)
2. [Architecture de Monitoring](#-architecture-de-monitoring)
3. [Outils de Monitoring Externes](#-outils-de-monitoring-externes)
4. [Outils de Monitoring Internes](#-outils-de-monitoring-internes)
5. [Debug des Complexités Spécifiques](#-debug-des-complexités-spécifiques)
6. [Alertes et Notifications](#-alertes-et-notifications)
7. [Bonnes Pratiques](#-bonnes-pratiques)
8. [Configuration Recommandée](#-configuration-recommandée)
9. [Checklists de Debug](#-checklists-de-debug)

---

## 🎯 Introduction

### Objectif

Ce document fournit une **boîte à outils complète** pour **monitorer, déboguer et maintenir** l'application DocumentFlow en production et en développement. Il couvre :

- Les **outils externes** (New Relic, Sentry, etc.)
- Les **outils internes** (logging, métriques custom)
- Le **debug des complexités spécifiques** (workflows, WOPI, notifications)
- Les **alertes et notifications** pour les problèmes
- Les **bonnes pratiques** de monitoring

### Public Cible

| Rôle | Utilisation |
|------|-------------|
| **Développeurs** | Debug quotidien, analyse des logs, metrics de code |
| **DevOps/SRE** | Configuration du monitoring, alertes, scalabilité |
| **Support Technique** | Diagnostic des problèmes utilisateurs |
| **Chefs de projet** | Vision globale de la santé du système |

### Prérequis

```
✅ Redis doit être configuré pour le caching et les queues
✅ Sidekiq/Solid Queue doit être opérationnel
✅ Postgres doit être configuré pour le logging des requêtes lentes
✅ Les credentials pour les services externes doivent être configurés
```

---

## 🏗️ Architecture de Monitoring

### Schéma Global

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              APPLICATION                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Rails     │  │   Puma      │  │  Sidekiq    │  │   Background Jobs    │ │
│  │   App       │  │   Server    │  │  /Solid Q   │  │   (WOPI, Notifs)     │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
└─────────┼──────────────┼──────────────┼──────────────┼──────────────────────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MONITORING LAYER                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  Structured  │  │   APM        │  │  Error       │  │  Custom        │ │
│  │  Logging     │  │  (New Relic) │  │  Tracking    │  │  Metrics       │ │
│  │  (Lograge)   │  │              │  │  (Sentry)    │  │  (Prometheus)  │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └───────┬─────────┘ │
└─────────┼──────────────┼──────────────┼──────────────┼─────────────────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           STORAGE & VISUALIZATION                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  ELK Stack   │  │  New Relic  │  │  Sentry      │  │  Grafana        │ │
│  │  (Logs)      │  │  (APM)       │  │  (Errors)    │  │  (Dashboards)   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
          │              │              │              │
          └──────────────┴──────────────┴──────────────┘
                                    │
                                    ▼
                          ┌───────────────┐
                          │  Alerting     │
                          │  (PagerDuty,  │
                          │   Slack,     │
                          │   Email)     │
                          └───────────────┘
```

### Flux de Données

```
1. Requête HTTP → Puma → Rails → Structured Logging
2. Requête lente → New Relic APM → Analyse des traces
3. Erreur → Sentry → Alerte au support
4. Job Sidekiq → Custom metrics → Prometheus → Grafana
5. WOPI call → Logging spécifique → New Relic Custom Events
6. Notification → Logging des broadcasts → Analyse des N+1
```

---

## 🔍 Outils de Monitoring Externes

### 1. New Relic (APM)

**Purpose:** Application Performance Monitoring (APM), Transaction Tracing, Infrastructure Monitoring

**Configuration:**

```ruby
# Gemfile
 Jules
# gem 'newrelic_rpm'

# newrelic.yml
production:
  license_key: <%= ENV['NEW_RELIC_LICENSE_KEY'] %>
  app_name: DocumentFlow-Prod
  distributed_tracing:
    enabled: true
  browser_monitoring:
    auto_instrument: true
  transaction_tracer:
    enabled: true
    transaction_threshold: 0.5  # 500ms
    stack_trace_threshold: 0.5
```

**Métriques Clés à Monitorer:**

| Métrique | Seuil | Action |
|----------|--------|--------|
| Response Time (Avg) | > 500ms | Investigate slow endpoints |
| Error Rate | > 1% | Check error logs |
| Throughput (RPM) | < 1000 | Check server resources |
| Database Time | > 50% of request | Optimize queries |
| External Calls Time | > 20% of request | Check WOPI latency |

**Dashboards Recommandés:**

```
┌─────────────────────────────────────────────────────────────┐
│ DocumentFlow - Overview Dashboard                           │
├─────────────────┬─────────────────┬─────────────────┬─────────┤
│ Response Time    │ Throughput       │ Error Rate       │ Apdex   │
│ Apdex Score      │ DB Time          │ External Time    │ CPU     │
│ Memory Usage     │ Queue Length     │ Background Jobs  │ WOPI    │
└─────────────────┴─────────────────┴─────────────────┴─────────┘

┌─────────────────────────────────────────────────────────────┐
│ DocumentFlow - WOPI Monitoring                               │
├─────────────────┬─────────────────┬─────────────────┬─────────┤
│ WOPI Call Count  │ WOPI Avg Time    │ WOPI Errors      │ Locks   │
│ Check-out Status │ File Sync Time   │ Format Support    │         │
└─────────────────┴─────────────────┴─────────────────┴─────────┘

┌─────────────────────────────────────────────────────────────┐
│ DocumentFlow - Database                                      │
├─────────────────┬─────────────────┬─────────────────┬─────────┤
│ Query Time       │ Slow Queries     │ Lock Waits       │ Cache   │
│ Connection Pool  │ Table Sizes       │ Index Usage      │ Hit Rate│
└─────────────────┴─────────────────┴─────────────────┴─────────┘
```

**Custom Events New Relic:**

```ruby
# app/services/new_relic_custom_events.rb
class NewRelicCustomEvents
  def self.track_wopi_call(document, user, operation, duration, success)
    NewRelic::Agent.record_custom_event(
      'WOPICall',
      {
        document_id: document.id,
        user_id: user.id,
        operation: operation,
        duration_ms: duration * 1000,
        success: success,
        entity_id: document.entity_id
      }
    )
  end
  
  def self.track_workflow_step(document, step, duration)
    NewRelic::Agent.record_custom_event(
      'WorkflowStep',
      {
        document_id: document.id,
        step_id: step.id,
        step_type: step.step_template.step_type,
        duration_ms: duration * 1000,
        assignee_id: step.assignee_id,
        entity_id: document.entity_id
      }
    )
  end
  
  def self.track_document_creation(document, duration)
    NewRelic::Agent.record_custom_event(
      'DocumentCreation',
      {
        document_id: document.id,
        reference_number: document.reference_number,
        duration_ms: duration * 1000,
        department_id: document.department_id,
        entity_id: document.entity_id
      }
    )
  end
  
  def self.track_notification(user, type, duration)
    NewRelic::Agent.record_custom_event(
      'Notification',
      {
        user_id: user.id,
        notification_type: type,
        duration_ms: duration * 1000,
        delivered_via: user.online? ? 'realtime' : 'persistent'
      }
    )
  end
end
```

**Intégration avec les services:**

```ruby
# app/services/wopi/file_service.rb
class Wopi::FileService
  def self.check_out_for_wopi(document, user)
    start_time = Time.current
    
    result = original_check_out_logic(document, user)
    
    duration = Time.current - start_time
    NewRelicCustomEvents.track_wopi_call(
      document, user, 'check_out', duration, result[:status] == :success
    )
    
    result
  end
end
```

---

### 2. Sentry (Error Tracking)

**Purpose:** Centralisation des erreurs, stack traces, reproductions

**Configuration:**

```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger]
  config.send_default_pii = false
  config.traces_sample_rate = 0.2  # 20% des transactions
  config.environment = Rails.env
  config.release = DocumentFlow::VERSION
  
  # Ignorer certaines erreurs
  config.excluded_exceptions += [
    'ActiveRecord::RecordNotFound',
    'Pundit::NotAuthorizedError',
    'ActionController::InvalidAuthenticityToken'
  ]
end
```

**Tags et Contexts Personnalisés:**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :sentry_context
  
  private
  
  def sentry_context
    Sentry.set_tags(
      entity_id: current_entity&.id,
      user_id: current_user&.id,
      department_id: current_department&.id
    )
    
    Sentry.set_user(
      id: current_user&.id,
      email: current_user&.email,
      ip_address: request.remote_ip
    )
    
    yield
  end
end
```

**Severity Levels:**

```ruby
# app/services/error_handler.rb
class ErrorHandler
  def self.report_to_sentry(error, context = {})
    severity = determine_severity(error)
    
    Sentry.capture_exception(error, **context.merge(severity: severity))
  end
  
  private_class_method def self.determine_severity(error)
    case error
    when Pundit::NotAuthorizedError
      :warning
    when ActiveRecord::RecordNotFound
      :info
    when WOPI::LockConflictError
      :warning
    when WOPI::AuthenticationError
      :error
    else
      :fatal
    end
  end
end
```

**Alertes Sentry:**

| Alerte | Condition | Notification |
|--------|-----------|--------------|
| Error Rate Spike | > 10 erreurs/min | Slack + PagerDuty |
| WOPI Errors | > 5 erreurs WOPI/h | Email team |
| Database Errors | Any database error | PagerDuty |
| Authentication Errors | > 10 auth errors/h | Security team |
| Performance Regression | Response time +50% | Slack |

---

### 3. Bullet (N+1 Query Detection)

**Purpose:** Détection des requêtes N+1 en développement et production

**Configuration:**

```ruby
# Gemfile
gem 'bullet', group: :development

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.growl = false
  Bullet.rails_logger = true
  Bullet.add_footer = true
  
  # Whitelist pour les fausses alertes
  Bullet.allow_dupe = false
  Bullet.allow_unused = false
  Bullet.allow_counter_sql = false
end

# Pour production (optionnel)
# config/environments/production.rb
if ENV['BULLET_ENABLED'] == 'true'
  Bullet.enable = true
  Bullet.alert = false
  Bullet.bullet_logger = true
  Bullet.rails_logger = true
end
```

**Utilisation:**

```ruby
# Dans les contrôleurs ou services
Bullet.start_request
# ... votre code ...
Bullet.end_request

# Ou automatiquement avec le middleware
# config/application.rb
config.middleware.use Bullet::Rack
```

**Exemple de sortie Bullet:**

```
N+1 Query detected
  Document => User
    APP/associations/document.rb:15:in `sender'
    APP/models/user.rb:10:in `full_name'
  Add to your finder: :include => [:sender]

N+1 Query counter cache
  Document => WorkflowStep
    APP/models/document.rb:25:in `workflow_steps_count'
  Add counter cache: `add_column :documents, :workflow_steps_count, :integer, default: 0`
```

---

### 4. Lograge (Structured Logging)

**Purpose:** Logging structuré pour une meilleure analyse

**Configuration:**

```ruby
# Gemfile
gem 'lograge'
gem 'logstash-logger'

# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  
  config.lograge.custom_options = lambda do |event|
    {
      time: event.time,
      remote_ip: event.payload[:remote_ip],
      user_id: event.payload[:user_id],
      entity_id: event.payload[:entity_id],
      request_id: event.payload[:request_id],
      dd: {
        trace_id: event.payload[:dd_trace_id],
        span_id: event.payload[:dd_span_id]
      }
    }
  end
end

# Pour les jobs
class ApplicationJob
  def serialize
    super.merge(
      job_class: self.class.name,
      job_id: job_id,
      entity_id: current_entity&.id,
      user_id: current_user&.id
    )
  end
end
```

**Middleware pour enrichir les logs:**

```ruby
# app/middleware/request_logger.rb
class RequestLogger
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Ajouter des infos au payload
    request.env['action_dispatch.request_id'] ||= SecureRandom.uuid
    
    # Enrichir le payload Lograge
    payload = {
      remote_ip: request.remote_ip,
      user_id: current_user&.id,
      entity_id: current_entity&.id,
      department_id: current_department&.id,
      request_id: request.env['action_dispatch.request_id']
    }
    
    # Datadog/APM trace IDs
    if ENV['DATADOG_ENABLED']
      payload[:dd_trace_id] = Datadog::Tracing.active_trace&.trace_id
      payload[:dd_span_id] = Datadog::Tracing.active_span&.span_id
    end
    
    env['action_dispatch.request.env'] = env['action_dispatch.request.env'].merge(payload)
    
    @app.call(env)
  end
end
```

**Exemple de log structuré:**

```json
{
  "method": "POST",
  "path": "/documents",
  "format": "json",
  "controller": "DocumentsController",
  "action": "create",
  "status": 201,
  "view_runtime": 45.6,
  "db_runtime": 123.4,
  "time": "2026-07-31T14:30:45.123Z",
  "params": {
    "document": {"subject": "Test"}
  },
  "remote_ip": "192.168.1.100",
  "user_id": 42,
  "entity_id": 5,
  "request_id": "abc123-def456",
  "dd": {
    "trace_id": "123456789",
    "span_id": "987654321"
  }
}
```

---

### 5. Datadog (Alternative APM)

**Configuration:**

```ruby
# Gemfile
gem 'ddtrace'
gem 'ddtrace-contrib'

# config/initializers/datadog.rb
Datadog.configure do |c|
  c.tracing.instrument :rails
  c.tracing.instrument :pg
  c.tracing.instrument :redis
  c.tracing.instrument :sidekiq
  c.tracing.analytics.enabled = true
  c.tracing.analytics.sample_rate = 0.5
  
  c.use :hooked, hook: :active_record
  c.use :hooked, hook: :action_cable
end
```

**Custom Metrics Datadog:**

```ruby
# app/services/datadog_metrics.rb
class DatadogMetrics
  def self.increment(counter, tags: [])
    Datadog::Statsd.increment(counter, tags: format_tags(tags))
  end
  
  def self.gauge(metric, value, tags: [])
    Datadog::Statsd.gauge(metric, value, tags: format_tags(tags))
  end
  
  def self.timing(metric, duration, tags: [])
    Datadog::Statsd.timing(metric, duration, tags: format_tags(tags))
  end
  
  def self.track_document_creation(document, duration)
    tags = [
      "entity:#{document.entity_id}",
      "department:#{document.department_id}",
      "user:#{document.user_id}"
    ]
    
    timing('documentflow.document.create', duration, tags: tags)
    increment('documentflow.document.count', tags: tags)
  end
  
  def self.track_wopi_call(document, operation, duration, success)
    tags = [
      "entity:#{document.entity_id}",
      "operation:#{operation}",
      "success:#{success}"
    ]
    
    timing('documentflow.wopi.call', duration, tags: tags)
    increment('documentflow.wopi.calls', tags: tags)
  end
  
  private_class_method def self.format_tags(tags)
    tags.map { |t| t.to_s.gsub(/[^a-zA-Z0-9_:.,-]/, '_') }
  end
end
```

---

### 6. Skylight (Alternative APM Simple)

**Configuration:**

```ruby
# Gemfile
gem 'skylight'

# config/skylight.yml
config:
  token: <%= ENV['SKYLIGHT_TOKEN'] %>
  environment: <%= Rails.env %>
  normalize_endpoints: true
```

---

## 🔧 Outils de Monitoring Internes

### 1. Health Checks

**Purpose:** Vérifier que l'application et ses dépendances sont en bonne santé

**Endpoint:** `/health` ou `/up`

```ruby
# config/routes.rb
get '/health', to: 'health#show'
get '/up', to: 'health#up'

# app/controllers/health_controller.rb
class HealthController < ActionController::Base
  def show
    checks = {
      database: check_database,
      redis: check_redis,
      storage: check_storage,
      wopi: check_wopi,
      cache: check_cache
    }
    
    status = checks.values.all? ? :ok : :service_unavailable
    
    render json: {
      status: status,
      timestamp: Time.current.utc,
      checks: checks,
      version: DocumentFlow::VERSION,
      environment: Rails.env
    }, status: status
  end
  
  def up
    # Simple check pour Kubernetes/load balancers
    if check_database && check_redis
      head :ok
    else
      head :service_unavailable
    end
  end
  
  private
  
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1').first
    true
  rescue => e
    { error: e.message }
  end
  
  def check_redis
    Redis.current.ping
    true
  rescue => e
    { error: e.message }
  end
  
  def check_storage
    return true unless Rails.application.config.active_storage.service == :local
    
    # Vérifier l'espace disque
    stat = File::Stat.new(Rails.root)
    available = stat.blocks_available * stat.blksize
    
    if available < 1.gigabyte
      { error: "Low disk space: #{available / 1.megabyte}MB" }
    else
      true
    end
  end
  
  def check_wopi
    return true unless Rails.application.config.wopi_enabled
    
    # Tester la connexion WOPI
    wopi_health_url = Rails.application.config.wopi_health_url
    
    response = Net::HTTP.get_response(URI.parse(wopi_health_url))
    response.code == '200' ? true : { error: "WOPI health check failed" }
  rescue => e
    { error: e.message }
  end
  
  def check_cache
    Rails.cache.fetch('health_check', expires_in: 1.minute) { true }
    true
  rescue => e
    { error: e.message }
  end
end
```

---

### 2. Rails Console Améliorée

**Configuration:**

```ruby
# config/initializers/console.rb
if defined?(Rails::Console)
  # Charger automatiquement les modèles
  Spring.watcher << Proc.new { Rails.application.reloader.reload! }
  
  # Alias utiles
  ActiveRecord::Base.alias_method :r, :reload
  ActiveRecord::Base.alias_method :c, :count
  ActiveRecord::Relation.alias_method :f, :first
  ActiveRecord::Relation.alias_method :l, :last
  
  # Méthodes utiles
  def entity(id)
    Entity.find(id)
  end
  
  def user(id)
    User.find(id)
  end
  
  def doc(id)
    Document.find(id)
  end
  
  def wopi_logs
    LogFile.tail('log/wopi.log', 50)
  end
end
```

---

### 3. Custom Logging

**Logger dédié pour les complexités:**

```ruby
# config/initializers/custom_loggers.rb
# Logger pour WOPI
wopi_logger = ActiveSupport::Logger.new(Rails.root.join('log/wopi.log'))
wopi_logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity} [WOPI] #{msg}\n"
end
WOPI_LOGGER = wopi_logger

# Logger pour les workflows
workflow_logger = ActiveSupport::Logger.new(Rails.root.join('log/workflows.log'))
workflow_logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity} [WORKFLOW] #{msg}\n"
end
WORKFLOW_LOGGER = workflow_logger

# Logger pour la numérotation
numbering_logger = ActiveSupport::Logger.new(Rails.root.join('log/numbering.log'))
NUMBERING_LOGGER = numbering_logger
```

**Utilisation:**

```ruby
# app/services/wopi/file_service.rb
class Wopi::FileService
  def self.check_out_for_wopi(document, user)
    WOPI_LOGGER.info("Check-out request - Document: #{document.id}, User: #{user.id}")
    
    result = perform_checkout(document, user)
    
    case result[:status]
    when :success
      WOPI_LOGGER.info("Check-out success - Lock: #{result[:lock_id]}")
    when :conflict
      WOPI_LOGGER.warn("Check-out conflict - #{result[:message]}")
    else
      WOPI_LOGGER.error("Check-out error - #{result[:message]}")
    end
    
    result
  end
end
```

---

### 4. Metrics Custom Rails

**Système de metrics interne:**

```ruby
# app/services/metrics.rb
class Metrics
  class << self
    private
    
    def redis
      Redis.current
    end
  end
  
  # Incrémenter un compteur
  def self.increment(key, value: 1, expiry: 1.hour)
    redis.multi do
      redis.incrby(key, value)
      redis.expire(key, expiry.to_i)
    end
  end
  
  # Définir une valeur
  def self.set(key, value, expiry: 1.hour)
    redis.setex(key, expiry.to_i, value)
  end
  
  # Obtenir une valeur
  def self.get(key)
    redis.get(key)
  end
  
  # Mesurer le temps d'exécution
  def self.timing(key, duration, expiry: 1.hour)
    increment("#{key}.count", expiry: expiry)
    set("#{key}.total_time", (get("#{key}.total_time").to_f + duration).to_s, expiry: expiry)
    set("#{key}.max_time", [get("#{key}.max_time").to_f, duration].max.to_s, expiry: expiry)
  end
  
  # Métriques WOPI
  def self.track_wopi(operation, duration, success)
    timing("wopi.#{operation}", duration)
    increment("wopi.#{operation}.#{success ? 'success' : 'failure'}")
  end
  
  # Métriques Workflows
  def self.track_workflow(step_type, duration, document_id)
    timing("workflow.#{step_type}", duration)
    set("workflow.#{step_type}.last_document", document_id)
  end
  
  # Métriques Notifications
  def self.track_notification(type, user_id, duration)
    timing("notification.#{type}", duration)
    increment("notification.#{type}.total")
  end
  
  # Exporter les métriques
  def self.export
    {
      wopi: {
        checkouts: get('wopi.check_out.count'),
        checkouts_time: get('wopi.check_out.total_time'),
        conflicts: get('wopi.check_out.failure')
      },
      workflows: {
        steps: redis.keys('workflow.*').map { |k| { key: k, value: get(k) } }
      },
      notifications: {
        total: redis.keys('notification.*').map { |k| get(k) }.sum
      }
    }
  end
end
```

---

### 5. Endpoint de Metrics

**Exposition des métriques pour monitoring externe:**

```ruby
# config/routes.rb
namespace :monitoring do
  get '/metrics', to: 'metrics#index'
  get '/metrics/json', to: 'metrics#json'
  get '/metrics/prometheus', to: 'metrics#prometheus'
end

# app/controllers/monitoring/metrics_controller.rb
module Monitoring
  class MetricsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_monitoring!
    
    def index
      @metrics = Metrics.export
    end
    
    def json
      render json: Metrics.export
    end
    
    def prometheus
      metrics = Metrics.export
      
      response = []
      
      # WOPI Metrics
      metrics[:wopi].each do |key, value|
        response << "wopi_#{key} #{value}"
      end
      
      # Workflow Metrics
      metrics[:workflows][:steps].each do |entry|
        response << "workflow_#{entry[:key]} #{entry[:value]}"
      end
      
      # Notification Metrics
      response << "notifications_total #{metrics[:notifications][:total]}"
      
      render plain: response.join("\n"), content_type: 'text/plain'
    end
    
    private
    
    def authenticate_monitoring!
      authenticate_or_request_with_http_basic do |username, password|
        username == ENV['MONITORING_USER'] && password == ENV['MONITORING_PASSWORD']
      end
    end
  end
end
```

---

### 6. Request IDs et Tracing

**Suivi des requêtes:**

```ruby
# app/middleware/request_id.rb
class RequestIdMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Générer un request ID unique
    request_id = env['action_dispatch.request_id'] ||= SecureRandom.uuid
    
    # Ajouter aux headers de réponse
    status, headers, body = @app.call(env)
    
    headers['X-Request-ID'] = request_id
    headers['X-Request-Processing-Time'] = (Time.current - request.start_time).to_s
    
    [status, headers, body]
  end
end

# config/application.rb
config.middleware.use RequestIdMiddleware
```

**Middleware de tracing:**

```ruby
# app/middleware/tracing_middleware.rb
class TracingMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Démarrer le tracing
    trace = {
      request_id: env['action_dispatch.request_id'],
      path: request.path,
      method: request.method,
      start_time: Time.current,
      user_id: current_user&.id,
      entity_id: current_entity&.id,
      steps: []
    }
    
    env['tracing.trace'] = trace
    
    begin
      status, headers, body = @app.call(env)
      
      # Finaliser le trace
      trace[:end_time] = Time.current
      trace[:duration] = trace[:end_time] - trace[:start_time]
      trace[:status] = status
      
      # Logger le trace
      Rails.logger.info("[TRACE] #{trace.to_json}")
      
      [status, headers, body]
    rescue => e
      trace[:error] = e.message
      trace[:backtrace] = e.backtrace.first(10)
      
      Rails.logger.error("[TRACE] #{trace.to_json}")
      
      raise
    end
  end
end
```

---

## 🎯 Debug des Complexités Spécifiques

### 1. Debug des Workflows

#### Problèmes Courants

| Problème | Symptôme | Solution |
|----------|----------|----------|
| Étapes parallèles bloquées | Document reste en in_progress | Vérifier `parallel_group_id` et `workflow_steps.status` |
| Rejet ne fonctionne pas | Document ne retourne pas en draft | Vérifier `can_reject?` et `after_reject` callback |
| Acteur manquant | Workflow bloqué | Vérifier `step.assignee` et réassigner automatiquement |
| Synchronisation AASM | État incohérent | Vérifier les callbacks AASM |

#### Outils de Debug

```ruby
# Rails console
# Vérifier l'état des workflows
def workflow_status(document_id)
  doc = Document.includes(:workflow_steps).find(document_id)
  
  puts "Document: #{doc.reference_number} (ID: #{doc.id})"
  puts "State: #{doc.state}"
  puts "\nWorkflow Steps:"
  
  doc.workflow_steps.order(:position).each do |step|
    puts "  - #{step.step_template.step_type} (#{step.status})"
    puts "    Assignee: #{step.assignee&.email} (#{step.assignee_id})"
    puts "    Parallel Group: #{step.step_template.parallel_group_id}"
    puts "    Created: #{step.created_at}, Updated: #{step.updated_at}"
  end
  
  puts "\nParallel Groups:"
  doc.workflow_steps.group_by { |s| s.step_template.parallel_group_id }.each do |group_id, steps|
    next unless group_id
    
    completed = steps.select(&:completed?).count
    total = steps.count
    
    puts "  Group #{group_id}: #{completed}/#{total} completed"
    steps.each do |step|
      puts "    - #{step.assignee&.email}: #{step.status}"
    end
  end
end
```

#### Logs Workflows

```ruby
# app/models/workflow_step.rb
class WorkflowStep < ApplicationRecord
  after_save :log_step_change
  
  private
  
  def log_step_change
    WORKFLOW_LOGGER.info(
      "Step #{id} changed - Document: #{document_id}, " \
      "Template: #{step_template_id}, Status: #{status}, " \
      "Assignee: #{assignee_id}, Changed: #{changed}"
    )
  end
end

# app/models/document.rb
class Document < ApplicationRecord
  after_commit :log_state_change, on: :update
  
  private
  
  def log_state_change
    return unless saved_change_to_state?
    
    WORKFLOW_LOGGER.info(
      "Document #{id} state changed - From: #{state_before_last_save}, " \
      "To: #{state}, Trigger: #{aasm.last_event}"
    )
  end
end
```

#### Debugger les problèmes de parallélisme

```ruby
# Tester les étapes parallèles
def test_parallel_workflow
  doc = Document.find(123)
  
  # Simuler la complétion d'une étape parallèle
  step = doc.workflow_steps.find(456)
  
  # Vérifier si le groupe parallèle est complet
  parallel_group = doc.workflow_steps
    .where(step_template: CircuitTemplateStep.where(parallel_group_id: step.step_template.parallel_group_id))
  
  all_completed = parallel_group.group_by(&:assignee_id).all? do |assignee_id, steps|
    steps.any?(&:completed?)
  end
  
  puts "Parallel group completed: #{all_completed}"
  
  # Forcer le processing
  Workflows::ParallelProcessor.process_step_completion(step)
end
```

---

### 2. Debug des Associations Polymorphiques

#### Problèmes Courants

| Problème | Symptôme | Solution |
|----------|----------|----------|
| N+1 queries | Logs slow, requêtes multiples | Utiliser `includes`, `preload`, ou cache |
| Requêtes OR complexes | Erreurs SQL | Utiliser des sous-requêtes ou UNION |
| Données orphelines | References nil | Nettoyer avec `depends: :destroy` ou `nullify` |
| Affichage générique | Erreurs de méthode | Vérifier `respond_to?` avant d'appeler |

#### Outils de Debug

```ruby
# Rails console
# Analyser les requêtes polymorphiques
def analyze_polymorphic_queries
  # Trouver les documents avec sender/addressee
  docs = Document.where.not(sender_id: nil).limit(100)
  
  # Analyser les types
  sender_types = docs.group_by(&:sender_type).transform_values(&:count)
  addressee_types = docs.group_by(&:addressee_type).transform_values(&:count)
  
  puts "Sender Types: #{sender_types}"
  puts "Addressee Types: #{addressee_types}"
  
  # Vérifier les orphelins
  orphaned_senders = docs.select do |d|
    d.sender_type.constantize.find_by(id: d.sender_id).nil?
  end
  
  puts "Orphaned senders: #{orphaned_senders.count}"
  
  orphaned_addressees = docs.select do |d|
    d.addressee_id && d.addressee_type.constantize.find_by(id: d.addressee_id).nil?
  end
  
  puts "Orphaned addressees: #{orphaned_addressees.count}"
end
```

#### Debug des N+1 Queries

```ruby
# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  def index
    # ACTIVER BULLET
    Bullet.enable = true if Rails.env.development?
    
    # Version non-optimisée (provoque N+1)
    @documents_bad = Document.order(created_at: :desc).limit(100)
    
    # Version optimisée
    @documents_good = Document
      .includes(:sender, :addressee)
      .order(created_at: :desc)
      .limit(100)
    
    # Version avec pré-chargement avancé
    @documents_best = Document
      .with_parties_eager
      .order(created_at: :desc)
      .limit(100)
    
    Bullet.perform_out_of_channel_notifications if Rails.env.development?
  end
end
```

#### Requêtes OR avec ActiveRecord

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # Problème: Comment trouver les documents où sender ou addressee est un user spécifique
  
  # Solution 1: OR (peut causer des problèmes avec certains types)
  scope :for_party, ->(party) {
    where(
      "(sender_type = ? AND sender_id = ?) OR (addressee_type = ? AND addressee_id = ?)",
      party.class.name, party.id, party.class.name, party.id
    )
  }
  
  # Solution 2: UNION (plus sûr mais plus lent)
  scope :for_party_union, ->(party) {
    from(
      union(
        where(sender_type: party.class.name, sender_id: party.id),
        where(addressee_type: party.class.name, addressee_id: party.id)
      ).as('documents')
    )
  }
  
  # Solution 3: Utiliser des foreign keys séparées
  scope :for_party_optimized, ->(party) {
    if party.is_a?(User)
      where("sender_type = 'User' AND sender_id = ? OR addressee_type = 'User' AND addressee_id = ?", party.id, party.id)
    elsif party.is_a?(Contact)
      where("sender_type = 'Contact' AND sender_id = ? OR addressee_type = 'Contact' AND addressee_id = ?", party.id, party.id)
    else
      none
    end
  }
end
```

---

### 3. Debug de la Numérotation

#### Problèmes Courants

| Problème | Symptôme | Solution |
|----------|----------|----------|
| Numéros dupliqués | Deux documents ont le même numéro | Vérifier `with_lock` et les transactions |
| Numéros manquants | Séquence avec trous | Vérifier les rollbacks et `update_column` |
| Année incohérente | Numéro avec mauvaise année | Utiliser `document_date.year` au lieu de `Time.current.year` |
| Concurrence | Erreurs de lock | Vérifier les timeouts de lock |

#### Outils de Debug

```ruby
# Rails console
# Analyser la numérotation
def analyze_numbering(department_id)
  department = Department.find(department_id)
  
  # Obtenir les derniers numéros
  docs = department.documents
    .where.not(reference_number: nil)
    .order(:reference_number)
    .last(20)
  
  puts "Derniers numéros pour #{department.name} (#{department.prefix}):"
  docs.each do |doc|
    puts "  #{doc.reference_number} - #{doc.subject} (ID: #{doc.id})"
  end
  
  # Vérifier les duplications
  duplicates = department.documents
    .group(:reference_number)
    .having('count(*) > 1')
    .count
  
  puts "\nNuméros dupliqués: #{duplicates}"
  
  # Vérifier les séquences
  docs_by_number = department.documents
    .where.not(reference_number: nil)
    .order(Arel.sql("SUBSTRING(reference_number FROM '#{department.prefix}[0-9]+')::bigint"))
    .pluck(:reference_number)
  
  expected = (1..docs_by_number.size).map { |n| "#{department.prefix}#{n.to_s.rjust(6, '0')}/2026" }
  
  missing = expected - docs_by_number
  extra = docs_by_number - expected
  
  puts "Numéros manquants: #{missing}"
  puts "Numéros extra: #{extra}"
end
```

#### Logs de Numérotation

```ruby
# app/services/documents/number_assignment_service.rb
module Documents
  class NumberAssignmentService
    def self.call(document:)
      new(document: document).call
    end
    
    def call
      NUMBERING_LOGGER.info("Assigning number to document #{@document.id}")
      
      result = assign_number_with_lock
      
      NUMBERING_LOGGER.info(
        "Number assigned: #{@document.reference_number} to document #{@document.id}"
      )
      
      result
    end
    
    private
    
    def assign_number_with_lock
      department.with_lock do
        NUMBERING_LOGGER.debug("Lock acquired for department #{department.id}")
        
        last_doc = find_last_document
        next_number = extract_number(last_doc.reference_number) + 1
        
        new_reference = "#{department.prefix}#{next_number.to_s.rjust(6, '0')}/#{@document.document_date.year}"
        
        NUMBERING_LOGGER.debug(
          "Next number: #{next_number}, Reference: #{new_reference}"
        )
        
        @document.reference_number = new_reference
        @document.save!
        
        new_reference
      end
    end
  end
end
```

#### Tester la Concurrence

```ruby
# spec/services/documents/number_assignment_service_concurrency_spec.rb
RSpec.describe 'NumberAssignmentService concurrency' do
  let(:entity) { create(:entity, prefix: 'TEST') }
  let(:department) { create(:department, entity: entity, prefix: 'DEP') }
  
  it 'handles concurrent numbering correctly' do
    threads = 10.times.map do |i|
      Thread.new do
        doc = build(:document, entity: entity, department: department)
        Documents::NumberAssignmentService.call(document: doc)
        doc.save!
      end
    end
    
    threads.each(&:join)
    
    # Vérifier que tous les numéros sont uniques
    numbers = Department.find(department.id).documents.pluck(:reference_number)
    expect(numbers.uniq.size).to eq(numbers.size)
    
    # Vérifier que la séquence est cohérente
    numbers_sorted = numbers.sort
    expected = (1..10).map { |n| "DEP#{n.to_s.rjust(6, '0')}/2026" }
    expect(numbers_sorted).to eq(expected)
  end
end
```

---

### 4. Debug de WOPI

#### Problèmes Courants

| Problème | Symptôme | Solution |
|----------|----------|----------|
| Conflit de lock | Erreur 409 Conflict | Vérifier `checked_out?` et `wopi_edit_url` |
| Token expiré | Erreur 401 Unauthorized | Vérifier `TOKEN_EXPIRY` et `verify_token` |
| Fichier non trouvé | Erreur 404 | Vérifier le lien entre WOPI et ActiveStorage |
| Permission refusée | Erreur 403 | Vérifier `calculate_permissions` |
| Timeout | Erreur 504 | Vérifier les timeouts et la latence réseau |

#### Outils de Debug

```ruby
# Rails console
# Analyser les locks WOPI
def wopi_locks
  # Trouver tous les checkouts actifs
  checkouts = DocumentCheckout.where(ended_at: nil)
  
  puts "Active WOPI Locks:"
  checkouts.each do |checkout|
    doc = checkout.document
    user = checkout.user
    
    puts "  Lock: #{checkout.lock_id}"
    puts "    Document: #{doc.reference_number} (ID: #{doc.id})"
    puts "    User: #{user.email} (ID: #{user.id})"
    puts "    Created: #{checkout.created_at}"
    puts "    Expires: #{checkout.expires_at}"
    puts "    Purpose: #{checkout.purpose}"
    puts ""
  end
  
  # Vérifier les documents avec WOPI activé
  wopi_docs = Document.where(entity: Entity.where(wopi_enabled: true))
  puts "Documents avec WOPI activé: #{wopi_docs.count}"
end
```

#### Logs WOPI

```ruby
# app/controllers/wopi_controller.rb
class WopiController < ApplicationController
  around_action :wopi_logging
  
  private
  
  def wopi_logging
    WOPI_LOGGER.info(
      "Request: #{request.method} #{request.path} - " \
      "IP: #{request.remote_ip}, User-Agent: #{request.user_agent}"
    )
    
    start_time = Time.current
    begin
      yield
      duration = Time.current - start_time
      WOPI_LOGGER.info("Response: #{response.status} - Duration: #{duration.round(3)}s")
    rescue => e
      duration = Time.current - start_time
      WOPI_LOGGER.error(
        "Error: #{e.class} - #{e.message} - " \
        "Duration: #{duration.round(3)}s - " \
        "Backtrace: #{e.backtrace.first(3).join(', ')}"
      )
      raise
    end
  end
end
```

#### Tester l'Authentification WOPI

```ruby
# spec/requests/wopi_authentication_spec.rb
RSpec.describe 'WOPI Authentication' do
  let(:entity) { create(:entity, wopi_enabled: true) }
  let(:user) { create(:user, entity: entity) }
  let(:document) { create(:document, entity: entity, user: user) }
  
  describe 'token validation' do
    it 'accepts a valid token' do
      token = Wopi::TokenService.generate_access_token(document, user)
      
      get "/wopi?token=#{token}", headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:ok)
    end
    
    it 'rejects an expired token' do
      payload = {
        doc_id: document.id,
        entity_id: entity.id,
        user_id: user.id,
        exp: 1.hour.ago.to_i
      }
      token = JWT.encode(payload, Wopi::TokenService::SECRET_KEY, 'HS256')
      
      get "/wopi?token=#{token}"
      
      expect(response).to have_http_status(:unauthorized)
    end
    
    it 'rejects a token with wrong entity' do
      other_entity = create(:entity)
      other_user = create(:user, entity: other_entity)
      token = Wopi::TokenService.generate_access_token(document, other_user)
      
      # Le document appartient à entity, mais le token est pour other_entity
      get "/wopi?token=#{token}"
      
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

#### Debug des Conflits

```ruby
# Tester les conflits de lock
def test_wopi_conflicts
  doc = Document.find(123)
  user1 = User.find(456)
  user2 = User.find(789)
  
  # User1 checkout
  result1 = Wopi::FileService.check_out_for_wopi(doc, user1)
  puts "User1 checkout: #{result1}"
  
  # User2 essaie de checker out
  result2 = Wopi::FileService.check_out_for_wopi(doc, user2)
  puts "User2 checkout: #{result2}"
  
  # User1 check in
  Wopi::FileService.check_in_from_wopi(doc, result1[:lock_id], "new content")
  
  # User2 peut maintenant checker out
  result3 = Wopi::FileService.check_out_for_wopi(doc, user2)
  puts "User2 checkout after check-in: #{result3}"
end
```

---

### 5. Debug des Notifications

#### Problèmes Courants

| Problème | Symptôme | Solution |
|----------|----------|----------|
| Notifications perdues | User ne voit pas ses notifications | Vérifier la persistance et le status online |
| Notifications dupliquées | Plusieurs notifications pour un même événement | Vérifier le throttling et la déduplication |
| Notifications N+1 | Logs slow quand on charge les notifications | Utiliser `includes` et le cache |
| Ordre des notifications | Notifications dans le mauvais ordre | Vérifier `created_at` et l'ordre des streams |
| Client déconnecté | Notifications non reçues | Implémenter un système de catch-up |

#### Outils de Debug

```ruby
# Rails console
# Analyser les notifications
def analyze_notifications(user_id)
  user = User.find(user_id)
  
  # Notifications non lues
  unread = user.notifications.unread.order(created_at: :desc)
  puts "Notifications non lues: #{unread.count}"
  
  unread.limit(10).each do |n|
    puts "  - #{n.notification_type} (#{n.id})"
    puts "    Document: #{n.document_id}"
    puts "    Metadata: #{n.metadata}"
    puts "    Created: #{n.created_at}"
    puts ""
  end
  
  # Notifications récentes
  recent = user.notifications.recent
  puts "Notifications récentes: #{recent.count}"
  
  # Vérifier le status online
  online = Redis.current.get("user:#{user.id}:online")
  puts "User online: #{online == 'true'}"
  
  # Vérifier les préférences de notification
  if user.notification_preferences
    puts "Email preferences: #{user.notification_preferences.email_preferences}"
  end
end
```

#### Logs des Notifications

```ruby
# app/services/notifications/persistent_dispatcher.rb
module Notifications
  class PersistentDispatcher
    def call
      notification = create_persistent_notification
      
      Rails.logger.info(
        "[NOTIFICATION] #{notification.notification_type} - " \
        "User: #{@user.id}, Document: #{@document&.id}, " \
        "Persistent: true, Online: #{user_online?}"
      )
      
      # ... rest of the method
    end
  end
end
```

#### Tester le Broadcast

```ruby
# spec/jobs/notification_broadcast_job_spec.rb
RSpec.describe NotificationBroadcastJob do
  let(:user) { create(:user) }
  let(:notification) { create(:notification, user: user) }
  
  before do
    allow(user).to receive(:online?).and_return(true)
    allow(ActionCable.server).to receive(:broadcast)
  end
  
  it 'broadcasts to online users' do
    expect(ActionCable.server).to receive(:broadcast).with(
      "user_#{user.id}_notifications",
      hash_including(html: anything, unread_count: 1)
    )
    
    described_class.perform_now(notification.id)
  end
  
  it 'does not broadcast to offline users' do
    allow(user).to receive(:online?).and_return(false)
    
    expect(ActionCable.server).not_to receive(:broadcast)
    
    described_class.perform_now(notification.id)
  end
end
```

#### Debug des Streams ActionCable

```ruby
# app/channels/notifications_channel.rb
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "user_#{current_user.id}_notifications"
    
    # Marquer l'utilisateur comme online
    Redis.current.setex("user:#{current_user.id}:online", 300, 'true')
    
    Rails.logger.info("[CABLE] User #{current_user.id} subscribed to notifications")
    
    # Envoyer les notifications non lues
    broadcast_unread_notifications
  end
  
  def unsubscribed
    # Marquer l'utilisateur comme offline
    Redis.current.del("user:#{current_user.id}:online")
    
    Rails.logger.info("[CABLE] User #{current_user.id} unsubscribed from notifications")
    
    stop_all_streams
  end
  
  private
  
  def broadcast_unread_notifications
    unread = current_user.notifications.unread.order(created_at: :desc)
    
    unread.each do |notification|
      transmit({
        html: ApplicationController.render(
          partial: 'notifications/notification',
          locals: { notification: notification }
        ),
        unread_count: unread.count,
        notification_id: notification.id
      })
    end
  end
end
```

---

## 🚨 Alertes et Notifications

### 1. Configuration des Alertes New Relic

```yaml
# newrelic_alerts.yml (exemple)
alerts:
  - name: High Error Rate
    condition:
      metric: errors.rate
      threshold: 0.05  # 5%
      duration: 5.minutes
    notification:
      channel: slack
      message: "High error rate detected in DocumentFlow"
    
  - name: Slow Response Time
    condition:
      metric: apdex
      threshold: 0.5  # Satisfying
      duration: 10.minutes
    notification:
      channel: pagerduty
      severity: warning
      
  - name: WOPI Errors
    condition:
      metric: custom.wopi.call.failure
      threshold: 5
      duration: 1.hour
    notification:
      channel: email
      recipients: ["team@documentflow.com"]
```

### 2. Configuration des Alertes Sentry

```yaml
# sentry_alerts.yml (exemple)
alerts:
  - id: 1
    name: "Critical Errors"
    conditions:
      - id: "sentry.rules.conditions.event_attribute.EventAttributeCondition"
        name: "An event's tags match"
        value: "level:fatal"
    actions:
      - id: "sentry.rules.actions.notify_event.NotifyEventAction"
        name: "Send a notification to Slack"
        target: "production-errors"
        
  - id: 2
    name: "WOPI Authentication Errors"
    conditions:
      - id: "sentry.rules.conditions.event_attribute.EventAttributeCondition"
        name: "An event's message contains"
        value: "WOPI Authentication"
    actions:
      - id: "sentry.rules.actions.notify_event.NotifyEventAction"
        name: "Send a notification to PagerDuty"
        target: "wopi-errors"
```

### 3. Alertes Custom avec Prometheus

```yaml
# prometheus_rules.yml
 groups:
 - name: documentflow.rules
   rules:
   - alert: HighWOPILatency
     expr: wopi_call_duration_seconds{quantile="0.95"} > 5
     for: 5m
     labels:
       severity: warning
     annotations:
       summary: "High WOPI latency (95th percentile > 5s)"
       description: "WOPI calls are taking longer than 5 seconds"
       
   - alert: HighErrorRate
     expr: rate(http_requests_total{status=~"5.."}[1m]) > 0.1
     for: 2m
     labels:
       severity: critical
     annotations:
       summary: "High error rate (>10%)"
       description: "More than 10% of requests are failing"
       
   - alert: DatabaseSlowQueries
     expr: rate(pg_query_duration_seconds_sum[1m]) / rate(pg_query_duration_seconds_count[1m]) > 1
     for: 5m
     labels:
       severity: warning
     annotations:
       summary: "Slow database queries"
       description: "Average query duration > 1 second"
       
   - alert: MemoryHighUsage
     expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
     for: 10m
     labels:
       severity: critical
     annotations:
       summary: "High memory usage (>90%)"
       description: "Server memory usage is critically high"
```

### 4. Alertes Slack

```ruby
# app/services/slack_alerts.rb
class SlackAlerts
  WEBHOOK_URL = ENV['SLACK_WEBHOOK_URL']
  
  def self.send(message, options = {})
    channel = options[:channel] || '#alerts'
    username = options[:username] || 'DocumentFlow Bot'
    severity = options[:severity] || 'info'
    
    color = case severity
            when 'critical' then '#ff0000'
            when 'warning' then '#ffcc00'
            when 'info' then '#36a64f'
            else '#36a64f'
            end
    
    payload = {
      channel: channel,
      username: username,
      attachments: [
        {
          color: color,
          title: "[#{severity.upcase}] #{Rails.env} - #{message[:title] || 'Alert'}",
          text: message[:text] || message,
          fields: message[:fields] || [],
          footer: "DocumentFlow - #{Time.current}",
          ts: Time.current.to_i
        }
      ]
    }
    
    HTTP.post(WEBHOOK_URL, json: payload)
  rescue => e
    Rails.logger.error("[SLACK] Failed to send alert: #{e.message}")
  end
  
  def self.alert_wopi_error(error, context)
    send(
      {
        title: "WOPI Error",
        text: "#{error.class}: #{error.message}",
        fields: [
          { title: 'Document', value: context[:document_id].to_s, short: true },
          { title: 'User', value: context[:user_id].to_s, short: true },
          { title: 'Operation', value: context[:operation].to_s, short: true },
          { title: 'Backtrace', value: error.backtrace.first(3).join("\n"), short: false }
        ]
      },
      channel: '#wopi-alerts',
      severity: 'warning'
    )
  end
  
  def self.alert_database_error(error, context)
    send(
      {
        title: "Database Error",
        text: "#{error.class}: #{error.message}",
        fields: [
          { title: 'Query', value: context[:query], short: false },
          { title: 'Backtrace', value: error.backtrace.first(5).join("\n"), short: false }
        ]
      },
      channel: '#db-alerts',
      severity: 'critical'
    )
  end
end
```

### 5. Intégration PagerDuty

```ruby
# app/services/pagerduty_alerts.rb
class PagerdutyAlerts
  ROUTING_KEY = ENV['PAGERDUTY_ROUTING_KEY']
  
  def self.trigger(incident_key, summary, severity, details = {})
    payload = {
      routing_key: ROUTING_KEY,
      event_action: 'trigger',
      dedup_key: incident_key,
      payload: {
        summary: summary,
        severity: severity,
        source: 'DocumentFlow',
        custom_details: details
      }
    }
    
    HTTP.post('https://events.pagerduty.com/v2/enqueue', json: payload)
  end
  
  def self.resolve(incident_key, summary)
    payload = {
      routing_key: ROUTING_KEY,
      event_action: 'resolve',
      dedup_key: incident_key,
      payload: {
        summary: summary,
        source: 'DocumentFlow'
      }
    }
    
    HTTP.post('https://events.pagerduty.com/v2/enqueue', json: payload)
  end
  
  def self.alert_critical_error(error, context)
    incident_key = "error-#{Digest::SHA256.hexdigest(error.message + Time.current.to_s)}"
    
    trigger(
      incident_key,
      "Critical Error in #{Rails.env}: #{error.class}",
      'critical',
      {
        error: error.message,
        backtrace: error.backtrace.first(10).join("\n"),
        context: context.except(:error, :backtrace)
      }
    )
  end
end
```

---

## ✅ Bonnes Pratiques

### 1. Logging

**✅ FAIRE:**
- Utiliser des logs structurés (JSON)
- Inclure `request_id` dans tous les logs
- Logger les erreurs avec contexte
- Utiliser des niveaux de log appropriés
- Logger les métriques de performance

**❌ NE PAS FAIRE:**
- Logger des informations sensibles (passwords, tokens)
- Logger en production avec niveau DEBUG
- Logger des objets entiers (utiliser `.as_json`)
- Négliger les logs dans les jobs background
- Oublier de logger les erreurs dans les callbacks

**Exemple de bon logging:**

```ruby
# BON
Rails.logger.info(
  "Document created",
  document_id: document.id,
  reference_number: document.reference_number,
  user_id: current_user.id,
  request_id: request.request_id,
  duration_ms: (Time.current - start_time) * 1000
)

# MAUVAIS
Rails.logger.info("Document created: #{document.inspect}")
```

### 2. Monitoring des Performances

**✅ FAIRE:**
- Monitorer le temps de réponse de chaque endpoint
- Monitorer le temps d'exécution des jobs background
- Monitorer les requêtes SQL lentes
- Monitorer la consommation mémoire
- Monitorer le taux d'erreur par endpoint

**❌ NE PAS FAIRE:**
- Ignorer les requêtes lentes
- Ne pas monitorer les dépendances externes
- Négliger les métriques des jobs background
- Oublier de monitorer le cache hit rate
- Ne pas alert sur les dégradations de performance

### 3. Gestion des Erreurs

**✅ FAIRE:**
- Capturer toutes les exceptions dans Sentry
- Classifier les erreurs (retryable vs permanent)
- Logger avec suffisamment de contexte
- Alertes pour les erreurs critiques
- Implémenter des mécanismes de retry intelligents

**❌ NE PAS FAIRE:**
- Avancer silencieusement sur les erreurs
- Négliger les erreurs dans les callbacks
- Ne pas classer les erreurs par gravité
- Oublier de logger les erreurs externes (WOPI, storage)
- Ne pas monitorer les erreurs des jobs background

### 4. Alertes

**✅ FAIRE:**
- Alertes pour les problèmes critiques (disponibilité, sécurité)
- Alertes pour les dégradations de performance
- Alertes pour les erreurs répétées
- Utiliser plusieurs canaux (Slack, PagerDuty, Email)
- Configurer des escalations

**❌ NE PAS FAIRE:**
- Alertes pour chaque erreur individuelle
- Alertes sans contexte suffisant
- Alertes qui spamment les canaux
- Négliger les alertes de monitoring
- Ne pas tester les alertes régulièrement

---

## 🔧 Configuration Recommandée

### 1. Production

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Logging
  config.log_level = :info
  config.lograge.enabled = true
  
  # APM
  config.newrelic.enabled = true
  config.sentry.dsn = ENV['SENTRY_DSN']
  
  # Metrics
  config.metrics.enabled = true
  config.metrics.export_interval = 1.minute
  
  # Health checks
  config.health_check.endpoint = '/health'
  config.health_check.interval = 30.seconds
end
```

### 2. Development

```ruby
# config/environments/development.rb
Rails.application.configure do
  # Logging
  config.log_level = :debug
  config.lograge.enabled = false
  
  # Bullet pour N+1
  config.after_initialize do
    Bullet.enable = true
    Bullet.alert = true
    Bullet.bullet_logger = true
  end
  
  # APM (optionnel)
  config.newrelic.enabled = ENV['NEW_RELIC_ENABLED'] == 'true'
  
  # Health checks
  config.consider_all_requests_local = false
end
```

### 3. Test

```ruby
# config/environments/test.rb
Rails.application.configure do
  # Désactiver le monitoring en test
  config.newrelic.enabled = false
  config.sentry.enabled = false
  
  # Activer Bullet en test
  config.after_initialize do
    Bullet.enable = true if ENV['BULLET_ENABLED']
    Bullet.alert = false
    Bullet.bullet_logger = false
  end
end
```

---

## 📋 Checklists de Debug

### 1. Problème de Workflow

**Symptômes:** Document bloqué, étape non complétée, état incohérent

- [ ] Vérifier les logs workflows (`log/workflows.log`)
- [ ] Examiner les `workflow_steps` du document concerné
- [ ] Vérifier les `parallel_group_id` pour les étapes parallèles
- [ ] Examiner les callbacks AASM dans le model `Document`
- [ ] Tester le service `Workflows::ParallelProcessor`
- [ ] Vérifier les permissions avec Pundit
- [ ] Examiner les jobs en queue (`SolidQueue::Job`)
- [ ] Tester en console avec les méthodes de debug

**Commandes utiles:**
```bash
# Voir les workflow_steps d'un document
tail -f log/workflows.log | grep 