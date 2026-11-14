# Architecture

What exists in the code today. When this file and the code disagree, the code wins — fix this file.

## Stack

Rails 8.1 · Ruby 3.4.5 · PostgreSQL · Propshaft + importmap · Hotwire (Turbo, Stimulus) ·
Tailwind (`tailwindcss-rails`) · ViewComponent · Devise (+ `devise-two-factor`, `webauthn`) ·
Pundit · AASM · `light-service` · Prawn (PDF stamping) · Solid Queue / Solid Cache / Solid Cable.
Document search is an `ILIKE` on `documents.search_text`.
Forms use `FloatingLabelsRails::FormBuilder` (app-wide default). Production file storage:
Cloudflare R2 (S3 API); development/test: local disk. UI text is English only.

## Multi-tenancy and access

- `Entity` is the tenant. A `User` belongs to entities through `EntityUser`, which carries the
  role (`owner`, `admin`, `member`, `guest`) and status (`pending`, `active`, `suspended`).
  Members join by invitation (`/invitations/:token`).
- `User#super_admin` (global flag) gives access to the hand-rolled `/admin` area: users,
  entities, audit logs and a read-only generic records browser
  (`Admin::ModelRegistry` is the allowlist; sensitive columns are redacted).
- Authorization is Pundit; role helpers (`entity_owner?`, `entity_admin?`, `entity_staff?`,
  `entity_guest?`) live in `ApplicationPolicy` and resolve the entity from the record.
- `Department` (flat, belongs to an entity) scopes documents. Members only see documents of
  their departments (via `EntityUserDepartment`), plus any document where they are a workflow
  actor. Owners/admins see everything in the entity. Every entity has a default department.
- Authentication: Devise with 30-minute inactivity timeout (`timeoutable`), no "remember me".
  Two-factor (TOTP + recovery codes) is mandatory for owners, admins and super admins.
  Passkeys (WebAuthn) can replace the password entirely; registering one makes an account
  passwordless.

## Documents

`Document` (AASM): `draft → in_progress → signed → finalized`, plus `cancelled`
(from draft/in_progress/signed). Events: `launch`, `sign`, `finalize`, `cancel`.

- `direction`: `outgoing` or `incoming`. Incoming documents never leave `draft`; `routed_at`
  marks them as released (`Document.settled` covers both cases).
- `sender` / `addressee` are polymorphic `User` or `Contact` (`PartyAssignable`, `Party`).
  `CcRecipient` links additional parties.
- **Numbering.** Outgoing documents get a provisional `PROV-<id>` at creation and their
  definitive `reference_number` when the SIGN step is approved. Incoming and email-archived
  documents get theirs on creation. Format `PREFIX(YYYY)NNNNN`
  (`ReferenceNumber`); prefix = department prefix, falling back to the entity prefix;
  sequence is per department and per year, serialized with a row lock on the department.
  Prefixes are mandatory on `Entity` and `Department` (≤ 8 chars, `A-Z0-9`).
- `main_file` (Active Storage) + `Annex` records (an annex can opt out of PDF conversion);
  `DocumentFileVersion` keeps replaced files. Signing freezes the document (`is_frozen`).
- Replies: `in_reply_to_id` builds a thread (shown as the "Document chain").
  `expects_response` and `response_deadline` drive the **ToDo / Waiting / Info** tabs
  (`Document.todo_for`, `waiting_for`, `info_for`); users can dismiss entries from
  Waiting/Info (`DocumentDismissal`). `ClassificationNode` is an entity-wide decimal filing
  tree (max depth 4, managed by owners/admins).
- `DistributionList`: per-user reusable recipient lists, applied to addressee + CC.
- Check-out/check-in: columns on `Document` (`checked_out_by`, …) — exclusive lock with
  versioned main-file replacement (`Documents::CheckOutOrganizer`, `CheckInOrganizer`).
- Shared links (`SharedLink`): public, token-based, expire after 15 days, renewable by the
  visitor once; previews of main file and annexes are served from `/share/:token`.

## Workflow circuit

`WorkflowStep` roles: `RED` (drafter), `VISA`, `SIGN`, `EXP` (dispatch); statuses `pending`,
`approved`, `rejected`, `skipped`; steps are ordered and may be grouped in parallel stages
(`is_parallel`, `parallel_group`). Rules enforced by the services:

- **Launch** requires at least one step, a SIGN step and a main file.
- A RED step cannot be rejected. Only the assigned actor can approve/reject/reassign; no
  action is possible while the document is checked out by someone else.
- A stage advances when all its steps are done. Approving SIGN signs the document (freezes it,
  assigns the reference number) and enqueues `PdfConversionJob` (stamping/conversion with
  `PdfStamper`/`PdfConverter`). When no step is pending the document is finalized
  (notifications to creator, addressee, CC).
- SIGN requires the signer to have a `SignatureImage` (encrypted in the DB, never served) and
  a WebAuthn step-up challenge (2-minute token). Stamping failures are strict.
- At EXP approval the actor edits the dispatch message/subject and chooses, per external
  recipient, a shared link or the PDF as an email attachment.
- `CircuitTemplate` / `CircuitTemplateStep`: reusable circuits cloned onto a document.
- `AuditLog` is append-only; `Shared::Actions::LogAuditEvent` is appended to every organizer
  unless it opts out.

## Incoming mail

`IncomingMails::RegisterOrganizer` registers an external mail with a Lead.
`IncomingMails::RouteOrganizer` routes it (action assignee, info recipients/CC) and can link
it to the outgoing document it replies to (`in_reply_to`), which removes that document from
the creator's Waiting tab.

## Templates

- `DocumentTemplate`: an uploaded `.docx` with `{{tag}}` placeholders; fields are detected
  automatically (`Templates::TagScanner`), a generation form is built dynamically, output is a
  `.docx` main file (`Templates::GenerateDocumentOrganizer`). Reserved tag: `date`.
- `EmailTemplate`: same mechanism for dispatch-message bodies (reserved: `date`,
  `recipient_name`). Staff can create templates; they are shared entity-wide unless restricted to one department.

## Email archive ingestion

`PollEmailArchiveMailboxJob` (every 5 min) reads one IMAP mailbox. Messages delivered to a
`Department#archive_ingestion_email` become auto-finalized outgoing documents
(`EmailArchive::CreateOrganizer`, BCC from Outlook); messages delivered to an
`Entity#incoming_archive_email` are registered as incoming mail by the redirecting user
(`EmailArchive::IncomingMailIngestor`). Skipped when the `EMAIL_ARCHIVE_IMAP_*` variables are unset.

## In-browser editing (WOPI)

`Wopi::FilesController` is the WOPI host; Collabora Online is the client. Access tokens
(`Wopi::AccessToken`, 4 h) replace the session. `CleanupStaleWopiCheckoutsJob` (hourly)
releases checkouts whose token expired. Disabled when `COLLABORA_BASE_URL` is unset.
See [wopi_collabora.md](wopi_collabora.md).

## Code layout

| Path | Role |
|---|---|
| `app/services/<domain>/` | `ApplicationService` organizers (`workflow_steps` DSL, wrapped in a DB transaction) and `ApplicationAction`s (`expects`, `executed`, `fail_with!`) |
| `app/policies/` | Pundit policies |
| `app/components/` | ViewComponents (`ui/` = generic kit, e.g. `Ui::ModalComponent`, `Ui::ConfirmModalComponent`) |
| `app/jobs/` | Notifications, Turbo Stream broadcasts, PDF conversion, reminders, cleanups, mailbox polling |
| `app/value_objects/` | `ReferenceNumber` |
| `spec/` | RSpec only (models, services, requests, components, jobs, system); previews in `spec/components/previews` |

## Background jobs

Solid Queue (in Puma in production via `SOLID_QUEUE_IN_PUMA`). Recurring (`config/recurring.yml`):
`ReminderJob` daily 09:00 (notifies actors of in-progress documents),
`CleanupExpiredLinksJob` daily 02:00, `CleanupStaleWopiCheckoutsJob` hourly,
`PollEmailArchiveMailboxJob` every 5 min, plus Solid Queue housekeeping in production.
Emails: `NotificationMailer`, `InvitationMailer`.
