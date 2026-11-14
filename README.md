# DocumentFlow

Multi-tenant document-workflow application (Rails 8.1, Ruby 3.4.5, PostgreSQL, Hotwire,
ViewComponent, Tailwind). Documents move through a RED → VISA → SIGN → EXP circuit;
incoming mail is registered and routed; everything is scoped to an `Entity` (tenant).

Production: <https://documentflowmanagement.com> (deployed with Kamal, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)).

## Documentation

| File | Content |
|---|---|
| [AGENTS.md](AGENTS.md) | Commands and conventions for contributors / coding agents |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | What the application does and how it is built |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Production topology, environment variables, rake tasks |
| [docs/wopi_collabora.md](docs/wopi_collabora.md) | In-browser editing: local Collabora + manual verification |
| [docs/demo/script.md](docs/demo/script.md) | Live-demo walkthrough (uses `db/demo_seed.rb`) |

## Getting started

Prerequisites: Ruby 3.4.5, PostgreSQL, LibreOffice
(`soffice`, used for PDF conversion), Chrome (JS system specs).

```bash
bin/setup --skip-server   # install gems, prepare the database
bin/rails db:seed         # optional sample data (all seeded users share one password, printed at the end)
bin/dev                   # Rails (PORT, default 3000) + Tailwind watcher via foreman
```

Background jobs run in a separate process in development: `bin/jobs`. Job dashboard: `/jobs`.

## Tests and linting

```bash
bin/rails db:test:prepare
bundle exec rspec          # full suite (SimpleCov always on, output in coverage/)
bundle exec rubocop        # rubocop-rails-omakase
bin/brakeman --no-pager && bin/bundler-audit && bin/importmap audit
```
