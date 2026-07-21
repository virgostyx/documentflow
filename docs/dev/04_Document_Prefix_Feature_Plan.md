# Document Prefix Feature — Implementation Plan

Status: DRAFT — pending user review/validation before any code is written.

## 1. Concept

Add a `prefix` attribute (max 8 chars) to both `Entity` and `Department`. The prefix is
baked into `Document#reference_number` at creation time, replacing the current
`YYYY/NNNNN` format with:

```
PREFIX(YYYY)NNNNN
```

Example: `ECESHQ(2026)00001`.

## 2. Decisions already validated with the user

| Question | Decision |
|---|---|
| Which prefix wins when a document has both an entity and a department? | The **department's** prefix. Entity's prefix is only a defensive fallback (see §6.3 — should never actually trigger once departments are backfilled). |
| Sequence scope | **Per department, per year.** Two departments (even in the same entity) each keep their own `00001, 00002, ...` counter. |
| Existing documents | **Regenerate all `reference_number` values** to the new format via a one-off migration task (see §7). |
| Is prefix mandatory? | **Yes, for both Entity and Department.** Enforced with a DB `NOT NULL` + presence validation. |

## 3. Data model changes

### 3.1 Migrations

```ruby
# AddPrefixToEntities
add_column :entities, :prefix, :string
add_index :entities, :prefix, unique: true

# AddPrefixToDepartments
add_column :departments, :prefix, :string
add_index :departments, [:entity_id, :prefix], unique: true
```

Columns are added nullable first, backfilled (see §7.1), then a follow-up migration
adds `NOT NULL`:

```ruby
change_column_null :entities, :prefix, false
change_column_null :departments, :prefix, false
```

(Same two-step pattern already used for `documents.department_id` —
`20260618113127_add_department_id_to_documents.rb` +
`20260618123933_add_null_constraint_to_documents_department_id.rb`.)

### 3.2 Model validations

`Entity` (`app/models/entity.rb`) and `Department` (`app/models/department.rb`) both get:

```ruby
validates :prefix, presence: true,
                    length: { maximum: 8 },
                    format: { with: /\A[A-Z0-9]+\z/, message: "must contain only uppercase letters and digits" }
```

- `Entity#prefix` uniqueness: global (`validates :prefix, uniqueness: true`), consistent
  with `name`/`code` which are already globally unique on `Entity`.
- `Department#prefix` uniqueness: scoped to `entity_id`, consistent with `name`'s current
  scoping (`app/models/department.rb:13`).
- A `before_validation :normalize_prefix` callback upcases the input, so a user typing
  `eceshq` gets `ECESHQ` — same pattern as `Entity#generate_code`.
- Charset is restricted to `[A-Z0-9]` (no punctuation, no `/`, `(`, `)`) because those
  characters are the format's own delimiters — allowing them would make parsing the
  reference number ambiguous.

**Open point to confirm:** should `Department#prefix` uniqueness also be enforced
*globally* (across entities), not just within the entity? Two unrelated entities could
otherwise both use `FIN`, producing identical-looking reference numbers
(`FIN(2026)00001`) for two different organizations. This is not a data-integrity issue
(everything is still scoped by `entity_id`/`department_id` internally) but could be
confusing if numbers are ever compared/exported across entities (e.g. shared links).
Default proposal: **entity-scoped only** (simpler, matches `name`'s existing pattern).
Flag if you want global uniqueness instead.

## 4. Number generation logic

### 4.1 New value object

Replace `app/value_objects/reference_number.rb` (or add a new class next to it —
TBD naming, suggest keeping the same class name since the old format disappears
entirely after the regeneration in §7):

```ruby
class ReferenceNumber
  FORMAT = /\A([A-Z0-9]{1,8})\((\d{4})\)(\d{5})\z/

  attr_reader :prefix, :year, :sequence

  def self.parse(value)
    match = FORMAT.match(value.to_s)
    return nil unless match
    new(prefix: match[1], year: match[2].to_i, sequence: match[3].to_i)
  end

  def self.first_for(prefix:, year:)
    new(prefix: prefix, year: year, sequence: 1)
  end

  def initialize(prefix:, year:, sequence: 1)
    @prefix = prefix
    @year = year
    @sequence = sequence
  end

  def next
    self.class.new(prefix: prefix, year: year, sequence: sequence + 1)
  end

  def to_s
    format("%s(%04d)%05d", prefix, year, sequence)
  end
  # ==, eql?, hash unchanged in spirit
end
```

### 4.2 `Document#generate_reference_number`

`app/models/document.rb:192-200` becomes:

```ruby
def generate_reference_number
  return if reference_number.present?
  return unless entity && department

  year = document_date&.year || Date.current.year
  prefix = department.prefix.presence || entity.prefix
  last = department.documents.where("reference_number LIKE ?", "#{prefix}(#{year})%").maximum(:reference_number)
  reference = last ? ReferenceNumber.parse(last).next : ReferenceNumber.first_for(prefix: prefix, year: year)
  self.reference_number = reference.to_s
end
```

Notes:
- Scoped on `department.documents` (not `entity.documents`) per the "per department"
  sequence decision.
- The `LIKE` scoping by `prefix` (rather than just by department+year) matters if a
  department's prefix is ever changed later: the sequence for the *new* prefix starts
  back at `1`, it does not continue the old prefix's count. This is a natural
  consequence of deriving the "last" number from the string itself rather than from an
  explicit counter. Flagging this now so it's a conscious choice, not a surprise later.
  Renaming a department's prefix should probably be a rare, deliberate admin action —
  not something to design heavily against for a first version.
- **Pre-existing behavior carried over unchanged:** the `where(...).maximum(...)` query
  is not safe under concurrent inserts (two documents created at the same instant in the
  same department could compute the same "last" and collide). This race already exists
  today in the entity-scoped version and is out of scope for this feature — not fixing
  it silently as a drive-by change. Worth a separate ticket if it ever causes a real
  collision in production.

## 5. UI / controller changes

- `app/controllers/entities_controller.rb:62` — add `:prefix` to permitted params.
- `app/controllers/entities/departments_controller.rb:62` — add `:prefix` to
  `department_params`.
- `app/views/entities/_form.html.erb` — add a `prefix` field (likely a plain text input,
  uppercased via JS or just left to the model callback + a re-render on validation
  error).
- `app/views/entities/departments/_form.html.erb` — same.
- `app/views/entities/settings/show.html.erb` — display each department's prefix next to
  its name in the department list (useful context for admins).
- No `EntityPolicy`/`DepartmentPolicy` changes needed — `update?` is already
  `entity_owner? || entity_admin?` for both, which is the right gate for editing a
  prefix (same as the recent `acronym`/`logo` additions, which needed no policy change).

## 6. Existing entities/departments — backfill

Because the column is mandatory, every existing `Entity` and `Department` row needs a
value before the `NOT NULL` migration runs.

### 6.1 Rake task: `lib/tasks/document_prefixes.rake`

`document_prefixes:backfill` — derives an initial prefix for every entity/department
that doesn't have one yet:

- Entity: derive from `acronym` if present (already validated ≤10 chars, just needs
  truncation to 8 + uppercase), else from `name` (strip non-alnum, take first 8 chars,
  uppercase).
- Department: derive from `name` the same way, prefixed/suffixed if needed to stay
  unique within the entity (e.g. append `2`, `3`, ... on collision — same idea as
  `Department`'s existing `is_default` "General" backfill in
  `lib/tasks/departments.rake`, per [[project_departments_feature]]).
- The auto-created `is_default` "General" department (created in the departments
  backfill) also needs a prefix — e.g. `"#{entity.prefix}GEN"` truncated to 8 chars.
- These are **placeholder values** — the plan assumes you (or entity/department admins)
  will review and edit them for real via the UI afterward. This task's job is only to
  satisfy the `NOT NULL` constraint without picking already-communicated document
  numbers apart.

This mirrors the existing precedent (`departments:backfill` rake task, kept separate
from an in-migration data change, per Rails best practice — see
[[project_departments_feature]]).

### 6.2 Sequencing of migrations/backfill

1. Add nullable `prefix` columns (§3.1 step 1).
2. Run `document_prefixes:backfill` rake task.
3. Add `NOT NULL` constraints (§3.1 step 2).
4. Deploy the new `Document#generate_reference_number` logic (§4.2) — from this point on,
   new documents get the new format.
5. Run the reference-number regeneration task (§7) for existing documents.

### 6.3 On the "fallback to entity prefix"

Since department `prefix` is `NOT NULL` from step 3 onward, `department.prefix.presence`
will always be truthy in practice — the `|| entity.prefix` fallback in §4.2 should never
actually fire in normal operation. It's kept purely as defensive code (e.g. protects
against a department created directly via console bypassing validations, or a future
migration gap), not a business rule anyone should rely on.

## 7. Regenerating existing documents' reference numbers

Per the user's decision, all existing `Document#reference_number` values are rewritten
to the new format — this is a **destructive, hard-to-reverse, all-rows write**. Treat it
with the same caution as any bulk production data migration:

- Take a database backup/snapshot immediately before running.
- Run it via a dedicated rake task (`documents:regenerate_reference_numbers`), not an
  inline migration, so it can be dry-run first.
- Support a `DRY_RUN=1` mode that prints the old → new mapping without writing, so you
  can eyeball a sample before committing.
- **Numbers already communicated externally (emails, printed letters, partner
  references) will no longer match what's in the system.** This was already flagged when
  you chose this option — noting it here again because it's the one irreversible
  decision in this plan. If there's any per-document audit trail or external references
  table that stores the *old* reference_number as a foreign lookup key, this would break
  it — worth a quick grep before running (current grep in §"Impact scan" below found none
  besides display-only usages).

### 7.1 Algorithm

For each `Department`, group its documents by `document_date.year` (falling back to
`created_at.year` if `document_date` is nil — matches current creation logic), order
chronologically by `(document_date, created_at)` — same tie-break already used by the
`sorted` scope (`app/models/document.rb:96-100`) — and reassign
`"#{department.prefix}(#{year})#{"%05d" % index}"` in that order, per year, starting at
`1`.

This preserves each document's *relative* chronological position within its department
but the actual numbers will differ from today's (expected — they're now scoped
per-department instead of per-entity).

## 8. Impact scan — who reads `reference_number`

Grepped the codebase: only `Document` and the `ReferenceNumber` value object *parse* it.
Everywhere else it's purely rendered as an opaque string (mailers, `_table.html.erb`
partials, `documents/show.html.erb`, `shared_links/show.html.erb`,
`thread_component.html.erb`, `documents_controller.rb`). None of those need any code
change — they'll just display the new format automatically. Confirmed no other model or
service depends on parsing its structure.

## 9. Tests

Following the project's TDD convention (Red → Green → Refactor per slice):

1. `spec/models/entity_spec.rb` — presence/length/format/uniqueness validations for
   `prefix`, normalization to uppercase.
2. `spec/models/department_spec.rb` — same, scoped uniqueness within entity.
3. `spec/value_objects/reference_number_spec.rb` — rewritten for the new `prefix(year)seq`
   format: parse, `next`, `first_for`, `to_s`, equality.
4. `spec/models/document_spec.rb` — update the existing reference-number generation spec
   (`document_spec.rb:191-192`) to assert the new format and per-department sequencing
   (two documents in *different* departments of the same entity, same year, both get
   `...00001`).
5. New rake task specs (or a plain integration test) for `document_prefixes:backfill`
   and `documents:regenerate_reference_numbers` — at minimum: uniqueness of generated
   placeholder prefixes on collision, and that regeneration preserves per-department
   chronological order.
6. System/request specs touching entity/department forms — add `prefix` to the
   valid-params fixtures used in `spec/requests` and `spec/system` (wherever
   `entity_params`/`department_params` factories currently omit it, factories under
   `spec/factories/entities.rb` and `spec/factories/departments.rb` need a `prefix`
   trait/sequence to keep existing specs green, since it'll become mandatory).

## 10. Suggested implementation order

1. Migrations (nullable columns) + model validations + factory updates (RED → GREEN on
   validation specs).
2. Backfill rake task + spec.
3. `NOT NULL` migrations.
4. `ReferenceNumber` value object rewrite + spec.
5. `Document#generate_reference_number` rewrite + spec (per-department scoping).
6. Controllers/views (permitted params, forms, settings page display).
7. Regeneration rake task + spec, run in a non-prod environment first, then production
   per §7's precautions.

## 11. Open items to confirm before starting

- [ ] Global vs. entity-scoped uniqueness for `Department#prefix` (§3.2).
- [ ] Exact backfill derivation rule for placeholder prefixes (§6.1) — acronym-first as
      proposed, or another source?
- [ ] Should `Entity#prefix` be edited through the existing `entities/_form.html.erb`
      (open to owner/admin like every other entity field), or does it warrant its own
      confirmation step given it feeds document numbering? Proposal: no extra
      confirmation needed, same as any other entity setting.
- [ ] Confirm no external system ingests/parses `reference_number` (only found
      in-app display usages in this repo — but if a downstream integration exists
      outside this codebase, the regeneration in §7 would affect it).
