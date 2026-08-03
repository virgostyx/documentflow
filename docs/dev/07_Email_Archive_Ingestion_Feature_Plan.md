# Email Archive Ingestion (Outlook → DocumentFlow) — Implementation Plan

Status: IMPLEMENTED (2026-08-03). 1721/1721 specs green (excluding one
pre-existing, unrelated flaky Capybara system spec in the classification
feature — confirmed flaky in isolation too, passes on rerun), RuboCop clean
on every file touched by this feature.

## 1. Concept

Two independent pipelines let emails exchanged via Outlook become
DocumentFlow documents automatically, without a human re-typing them into
the app:

- **Outgoing** — a user BCCs a dedicated department address when *sending*
  mail from Outlook. The mail is already sent, so there's nothing to
  approve: the resulting `Document` is created already "done" (`status:
  "finalized"`), never enters the RED→VISA→SIGN→EXP circuit.
- **Incoming** — a user sets up an Outlook/Exchange rule to *redirect* (or
  manually forwards as an attachment) a copy of mail they *receive* to a
  dedicated entity-wide address. This maps directly onto the existing
  "Incoming Mail" feature (manual registration + Lead triage/routing): the
  relaying user becomes the Lead, filed under their own primary department,
  and the existing triage/routing UI is reused completely unmodified.

Both pipelines are fed by one Solid Queue recurring job
(`PollEmailArchiveMailboxJob`) that polls a single shared IMAP mailbox every
5 minutes and dispatches each unseen message by matching its
`Delivered-To`/`X-Original-To` header against configured addresses. There
was no inbound-email infrastructure in the app before this feature (no
ActionMailbox, no IMAP gem) — this is greenfield.

## 2. Decisions validated with the user

| Question | Decision |
|---|---|
| Outgoing lifecycle: new approval state, or reuse an existing one? | **Reuse `status: "finalized"` directly**, set on `Document.new` (not via an AASM `event!`). A new `archived_from_email` boolean flag distinguishes these for badge/audit purposes only — every other scope/query that already keys off `.finalized` (list, sidebar counts, shareable links, edit-lock policy) needed zero changes. |
| Outgoing: how is the department resolved with no human filling a form? | **One dedicated BCC address per department**, admin-configured (`Department#archive_ingestion_email`). |
| Incoming: who becomes the Lead? | **The user who set up the redirect/forward**, resolved via `Resent-From` (Redirect) or the outer message's `From:` (Forward-as-attachment). Their `primary_department` picks the department automatically — no per-department address needed for this flow, just **one address per entity** (`Entity#incoming_archive_email`). |
| Incoming: how does the mail arrive intact? | **Outlook/Exchange "Redirect" rule** (preferred — preserves original headers via RFC 5322 `Resent-*` fields) with **"Forward as attachment"** as the documented per-message fallback (original nested as a `message/rfc822` attachment) if `Resent-From` isn't populated in a given Exchange environment. Plain inline "Forward" (quoted body, no reliable structure) is explicitly unsupported. |
| Sender identity mapping | New `User#external_email` — an Outlook/corporate address that may differ from the DocumentFlow login email. Used by both pipelines to resolve the acting user. |
| Transport | Plain IMAP polling (`net-imap` + `mail` gems), no Microsoft Graph/Azure app registration. |
| Anti-spoofing | `From:`/`Resent-From` are trusted only when they match a **known `external_email`/`email` of a user who is an active member of the resolved entity/department** — bounds impersonation to known internal users. SPF/DKIM verification is a documented follow-up, not built. |

## 3. Schema

```ruby
# AddExternalEmailToUsers
add_column :users, :external_email, :string
add_index :users, :external_email, unique: true

# AddIncomingArchiveEmailToEntities
add_column :entities, :incoming_archive_email, :string
add_index :entities, :incoming_archive_email, unique: true

# AddArchiveIngestionEmailToDepartments
add_column :departments, :archive_ingestion_email, :string
add_index :departments, :archive_ingestion_email, unique: true   # global, not scoped to entity

# AddArchivedFromEmailToDocuments
add_column :documents, :archived_from_email, :boolean, default: false, null: false
```

All three email fields are optional, format-validated
(`URI::MailTo::EMAIL_REGEXP`), and normalized to lowercase on
`before_validation` — same pattern as `Department#prefix`'s
`normalize_prefix`.

## 4. Shared building blocks

- `EmailArchive::ExtractOriginalMessage` — given a raw `Mail::Message`,
  returns the "true" original message and who relayed it, handling both
  incoming delivery styles uniformly (nested `message/rfc822` attachment vs.
  top-level message + `Resent-From`/`Resent-Sender`).
- `EmailArchive::RenderBodyToPdf` — renders a message's HTML part (falling
  back to the plain-text part wrapped in minimal HTML) to a PDF-attachable
  hash, used as `main_file` by both pipelines. Required extending
  `PdfConverter::LIBREOFFICE_EXTENSIONS` with `.html` — LibreOffice headless
  already handles HTML→PDF, so no new conversion path was needed.
- `EmailArchive::Actions::ResolveOriginalSenderContact` — generic find-or-create
  `Contact` from an email address + optional display name, scoped to an
  entity. Reused by both pipelines (as the incoming "original sender" and
  the outgoing "addressee"/"cc recipient" resolver).
- `PollEmailArchiveMailboxJob` (`app/jobs/`) — IMAP polling via `net-imap`,
  message parsing via `mail`. No-ops entirely (never connects) when
  `EMAIL_ARCHIVE_IMAP_HOST`/`_USERNAME`/`_PASSWORD` aren't set. Marks every
  processed message `\Seen` in an `ensure` block, whether it succeeded or
  was permanently unmatched, so nothing is ever reprocessed. Registered in
  `config/recurring.yml` (`every 5 minutes`, both `development` and
  `production`).

## 5. Incoming pipeline

`EmailArchive::IncomingMailIngestor` resolves the relaying `EntityUser`
(`Actions::ResolveRedirectingUser`, via `external_email`/`email` + active
entity membership + a `primary_department`) and the original external
sender `Contact`, then calls the **existing, unmodified**
`IncomingMails::RegisterOrganizer` — since `department_id` is always the
relaying user's own `primary_department` and `lead_user_id` is always that
same user, `RegisterOrganizer`'s membership-validation steps
(`ValidateDepartmentMembership`, `ValidateLeadDepartmentMembership`) pass
trivially. Once created, the document is indistinguishable from a
manually-registered incoming mail: it appears in
`pending_triage_for(relaying_user)` and is routed via the existing UI. No
forced PDF conversion of annexes (matches current manual-registration
behavior — only the body→`main_file` goes through `PdfConverter`).

## 6. Outgoing pipeline

`EmailArchive::CreateOrganizer` (new `LightService` organizer,
`app/services/email_archive/`), steps: `ResolveDepartment` →
`ResolveSenderUser` (anti-spoofing boundary — owner/admin bypass or
department membership required) → `ResolveExternalAddressee` (first `To:`
recipient; remaining `To:`/`Cc:` carried forward) → `CreateArchivedDocument`
(builds the `Document` already `status: "finalized"`, `is_frozen: true`,
`archived_from_email: true`, no `workflow_steps`, sets the audit-log ctx
keys the same way `IncomingMails::Actions::RegisterIncomingMail` does) →
`AttachEmailContent` (body→PDF `main_file`; each real attachment becomes an
`Annex`, best-effort converted to PDF via `PdfConverter`, non-fatal per
attachment — falls back to the raw file and logs a warning on conversion
failure) → `CreateCcRecipients`.

`Document#generate_reference_number`/`#assign_temporary_number`'s trigger
conditions were widened from `if: :incoming?` to
`if: -> { incoming? || archived_from_email? }` (and the inverse for
`unless:`) — archived-from-email documents get their definitive
`reference_number` immediately, exactly like incoming mail, reusing the
same private method with no duplication.

## 7. UI

- Settings: `devise/registrations/edit.html.erb` (`external_email`),
  `entities/_form.html.erb` (`incoming_archive_email`),
  `entities/departments/_form.html.erb` (`archive_ingestion_email`) — all
  optional fields, `FloatingLabelsRails` pattern matching existing
  `prefix`/`email` fields.
- `Documents::DocumentStatusBadgeComponent` gained an `archived_from_email:`
  kwarg — renders "Archived from Outlook" (info color) instead of
  "Finalized" (success color) when true. All four call sites
  (`documents/show`, `shared_links/show`, `thread_component`,
  `document_state_badge_component`) updated to pass
  `document.archived_from_email?`. Every other status/badge/scope behavior
  is untouched.

## 8. Deploy

`config/deploy.yml`: `EMAIL_ARCHIVE_IMAP_USERNAME`/`_PASSWORD` added to
`env.secret`; `EMAIL_ARCHIVE_IMAP_HOST`/`_PORT` added to `env.clear`
(`imap.hostinger.com` / `993`, same host family as the existing SMTP
config). `.kamal/secrets` got placeholder lines (`CHANGE_ME`) — **real
mailbox credentials still need to be filled in before the job does anything
in production**; until then it silently no-ops (see `imap_configured?`).

## 9. Tests

`spec/support/mail_fixtures.rb` builds in-memory `Mail::Message` fixtures
(`build_archive_mail`, `build_forwarded_mail`) — no real IMAP connection or
network activity anywhere in the suite. Coverage: `ExtractOriginalMessage`
(both delivery styles), `IncomingMailIngestor` (happy path, unmatched
entity/user, missing Resent-From), `CreateOrganizer` (happy path incl.
cc_recipients/audit log, unmatched department, unauthorized sender, no
To: recipient), `PollEmailArchiveMailboxJob` (unconfigured no-op, empty
mailbox, dispatch to both pipelines, unmatched address still marks seen,
per-message error doesn't propagate) — IMAP fully stubbed via
`instance_double(Net::IMAP)`. Plus model-level validation/normalization
specs for the three new email fields and the widened
`Document` reference-number callback.

## 10. Known limitations

- **`Resent-From` assumption not verified against a real Exchange/Outlook
  tenant** — this determines whether the Redirect path works as designed or
  users need to be instructed to use "Forward as attachment" instead. Do
  this before rolling out to real users: set up a redirect rule to a test
  entity's `incoming_archive_email` and inspect the raw headers that
  actually arrive.
- **No SPF/DKIM verification** — the anti-spoofing boundary is "matches a
  known internal user's address," not cryptographic proof of origin. Fine
  for an internal archival tool; would need hardening if the ingestion
  mailbox were ever exposed more broadly.
- **IMAP credentials are placeholders** (`.kamal/secrets`) — the feature is
  fully wired but inert in production until real mailbox credentials are
  provisioned.
