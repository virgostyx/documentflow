# Deployment

Source of truth: `config/deploy.yml` (Kamal 2). Deploys are built from the git clone, not the
working tree — commit before `bin/kamal deploy`.

## Topology (single server)

| Piece | Details |
|---|---|
| App | `virgostyx/documentflow` image, kamal-proxy with TLS on `documentflowmanagement.com`, Puma + Thruster on port 3000, Solid Queue inside Puma (`SOLID_QUEUE_IN_PUMA`) |
| Database | `postgres:16-alpine` accessory, bound to `127.0.0.1:5432` |
| Collabora Online | `collabora/code` accessory, proxied at `office.documentflowmanagement.com` (TLS terminated by kamal-proxy, `ssl.termination=true`, `net.frame_ancestors` set to the app host) |
| Files | Cloudflare R2 bucket (Active Storage `:cloudflare` service); the `documentflow_storage` volume is mounted at `/rails/storage` |
| Mail | SMTP (`SMTP_*`, `DEFAULT_FROM_EMAIL`) |
| Server access | SSH on a non-default port with key-only auth (see `ssh:` in `deploy.yml`) |

Useful aliases: `bin/kamal console`, `shell`, `logs`, `dbc`.

## Environment

Secrets (`.kamal/secrets`): `RAILS_MASTER_KEY`, `DOCUMENTFLOW_DATABASE_PASSWORD`, `POSTGRES_PASSWORD`,
`SMTP_USERNAME`, `SMTP_PASSWORD`, `AR_ENCRYPTION_*` (primary, deterministic, key-derivation salt —
used by encrypted attributes such as `SignatureImage`), `CLOUDFLARE_R2_ACCESS_KEY_ID`,
`CLOUDFLARE_R2_SECRET_ACCESS_KEY`, `EMAIL_ARCHIVE_IMAP_USERNAME`, `EMAIL_ARCHIVE_IMAP_PASSWORD`,
`COLLABORA_ADMIN_USERNAME`, `COLLABORA_ADMIN_PASSWORD`, `KAMAL_REGISTRY_PASSWORD`.

Plain variables read by the app: `DB_HOST`, `CLOUDFLARE_R2_BUCKET`, `CLOUDFLARE_R2_ENDPOINT`,
`SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `DEFAULT_FROM_EMAIL`, `EMAIL_ARCHIVE_IMAP_HOST`,
`EMAIL_ARCHIVE_IMAP_PORT`, `COLLABORA_BASE_URL`, `WEB_CONCURRENCY`, `RAILS_MAX_THREADS`,
`RAILS_LOG_LEVEL`, `JOB_CONCURRENCY`.

Optional features switch off when their variables are unset: Collabora editing
(`COLLABORA_BASE_URL`) and email-archive polling (`EMAIL_ARCHIVE_IMAP_*`).

## Rake tasks (`lib/tasks`)

| Task | Purpose |
|---|---|
| `departments:backfill` | Create a default department per entity and assign it to existing documents |
| `document_prefixes:backfill` | Give every entity/department without one a placeholder prefix |
| `documents:regenerate_reference_numbers` | Rebuild all reference numbers as `PREFIX(YYYY)NNNNN`; `DRY_RUN=1` previews |

## CI

`.github/workflows/ci.yml` runs Brakeman, bundler-audit, `importmap audit`, RuboCop and the
full RSpec suite (`bundle exec rspec`, Postgres service, LibreOffice and Chrome installed).
