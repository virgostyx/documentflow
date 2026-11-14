# AGENTS.md

DocumentFlow: a multi-tenant Rails 8.1 document-workflow app (Ruby 3.4.5, PostgreSQL, RSpec, ViewComponent, Hotwire).

## Running tests

- Run the full suite: `bundle exec rspec`
- One file: `bundle exec rspec spec/models/document_spec.rb`
- One line: `bundle exec rspec spec/models/document_spec.rb:42`
- By type: `bundle exec rspec spec/services`, `spec/requests`, `spec/components`, `spec/system`, etc.
- SimpleCov runs unconditionally on every RSpec run (no `COVERAGE=true` needed) and writes to `coverage/`.
- System specs default to `rack_test`; specs tagged `js: true` use headless Chrome via Selenium (already installed in this environment).
- **`bin/rails test` / `bin/rails test:system` are Minitest tasks and do nothing here** — there is no `test/` directory; everything lives under `spec/` (RSpec). CI runs `bundle exec rspec`.
- Postgres must be running and `test` DB migrated first: `bin/rails db:test:prepare` (or `db:prepare`).

## Linting / security

- `bundle exec rubocop` — style is `rubocop-rails-omakase` (see `.rubocop.yml`); no local override rules beyond the omakase base.
- `bin/brakeman --no-pager` and `bin/bundler-audit` mirror the CI `scan_ruby` job.
- `bin/importmap audit` mirrors the CI `scan_js` job.
- CI order (`.github/workflows/ci.yml`): `scan_ruby` + `scan_js` + `lint` run independently, `test`/`system-test` need Postgres.

## Dev servers

- `bin/dev` (Procfile.dev) starts both `bin/rails server` and `bin/rails tailwindcss:watch` via foreman. Don't forget the Tailwind watcher — CSS classes silently stop updating without it.
- Background jobs: Solid Queue (`bin/jobs`, i.e. `bin/rails solid_queue:start`), no Redis. Jobs UI lives at `/jobs` (mission_control-jobs).

## Architecture

- **Multi-tenant**: everything hangs off `Entity` (tenant). Membership/role (`owner/admin/member/guest`) lives on `EntityUser`, not on `User`. Authorization helpers (`entity_owner?`, `entity_admin?`, `entity_staff?`, etc.) live in `app/policies/application_policy.rb` and resolve the entity via `record.entity`/`record` itself.
- **Documents** are AASM state machines (`draft → in_progress → signed → finalized`, plus `cancelled`) scoped to `Entity` + `Department`. `sender`/`addressee` are polymorphic (`User` or `Contact`, via `PartyAssignable` concern) — this supports both internal workflow docs and incoming/outgoing mail. Reference numbers are generated per-`Department` (`reference_number` prefix comes from `department.prefix` or falls back to `entity.prefix`).
- **Service layer**: `app/services` uses the `light-service` gem (Organizer + Action), not a hand-rolled framework. Base classes: `ApplicationService` (`extend LightService::Organizer`, wraps `steps` in a DB transaction) and `ApplicationAction` (`extend LightService::Action`, provides `fail_with!`/`succeed_with!`/`handle_error`). Organizers declare steps via the `workflow_steps` DSL, e.g.:
  ```ruby
  class Documents::LaunchOrganizer < ApplicationService
    workflow_steps Actions::ValidateHasCircuit, Actions::LaunchDocument, Actions::NotifyFirstActor
  end
  ```
  `workflow_steps` auto-appends `Shared::Actions::LogAuditEvent` unless called with `audit_log: false`. Actions declare `expects :foo` and use `executed do |ctx| ... end`.
- Other load-bearing domains: `CircuitTemplate`/`CircuitTemplateStep` (reusable workflow templates), `Department`/`EntityUserDepartment` (department-scoped membership, gates document access), `ClassificationNode` (document filing/taxonomy), `IncomingMail` services (mail intake/routing), check-out/check-in locking of a document (columns on `Document`, `Documents::CheckOutOrganizer`/`CheckInOrganizer`), `CcRecipient`, `Annex`/`DocumentFileVersion` (file versioning).
- Forms use `FloatingLabelsRails::FormBuilder` as the app-wide default form builder (`config.action_view.default_form_builder`), not plain `form_with`.
- ViewComponent previews live under `spec/components/previews`, registered via `config.view_component.previews.paths` (not the Rails default `app/components/previews` location).

## Docs

`README.md` links to `docs/ARCHITECTURE.md` (what exists), `docs/DEPLOYMENT.md`, `docs/wopi_collabora.md` and `docs/demo/`. They are kept in sync with the code; if you change behavior they describe, update them in the same commit. Old planning documents were removed (see git history before the 2026-11 docs cleanup).
