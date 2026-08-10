# Refactor Audit — 2026-08-10

Preventive tech-debt audit. No specific pain point reported; goal is to surface the best
refactor candidates before the next feature cycle. Generated with `rubocop`, `flog`, `flay`,
and `reek` (flog/flay/reek installed standalone via `gem install --user-install`, not added
to the Gemfile), cross-referenced with file size and existing spec coverage.

**Headline finding:** the codebase is in good shape overall. RuboCop is essentially clean
(1 auto-correctable offense), only 2 files exceed 200 lines, and most reek/flay hits are
minor local smells rather than structural rot. The candidates below are the ones worth
spending time on; everything else is noise-level for a project this size.

## How to read this list

Ranked by **(value ÷ (risk × effort))** — quick, safe, high-value wins first. Each item
follows the existing TDD-strict workflow: tests green before, small commits, tests green
after. "Spec safety net" notes whether there's direct coverage to refactor against.

---

## 1. Extract shared "policy defaults" module (quick win)

- **Where:** `app/policies/document_template_policy.rb` & `email_template_policy.rb`
  (flay: IDENTICAL class body, mass×2=296); `classification_node_policy.rb`,
  `contact_policy.rb`, `department_policy.rb` (flay: IDENTICAL class body, mass×3=189)
- **Problem:** Two clusters of policies with byte-for-byte identical bodies.
- **Fix:** Extract into a shared concern/base (e.g. `EntityScopedPolicy`) that the
  policies `include` or inherit from, keeping only what actually differs.
- **Risk:** Low — pure structural dedup, behavior unchanged.
- **Effort:** Low (~1 hour).
- **Spec safety net:** Good — all have specs except `contact_policy.rb` (no spec found;
  add one as part of this refactor, cheap since it'll mirror the others).

## 2. Extract "respond to organizer result" controller concern

- **Where:** `app/controllers/documents_controller.rb` (reek: `RepeatedConditional`
  tests `result.success?` **6 times**; `DuplicateMethodCall` on
  `entity_document_path(current_entity, @document)` in `cancel`, `classify`, `launch`)
  and `app/controllers/workflow_steps_controller.rb` (same `result.success?` /
  `entity_document_path` pattern in `create`, `update`, `apply_template`)
- **Problem:** The "call an organizer, redirect with flash on success, re-render with
  errors on failure" pattern is hand-written per action across two of the app's
  busiest controllers.
- **Fix:** A small controller concern, e.g. `respond_to_organizer(result, success_path:)`,
  used by both controllers. This is the single highest-value item on the list — it's the
  same shape as several of the `flog` complexity hits (`DocumentsController#classify`,
  `WorkflowStepsController#confirm_exp`).
- **Risk:** Medium — high-traffic controllers, central to the RED→VISA→SIGN→EXP flow.
- **Effort:** Medium (~half day, touching two controllers + shared concern + specs).
- **Spec safety net:** Good — `spec/requests/documents_spec.rb`,
  `spec/requests/workflow_steps_spec.rb`, `spec/requests/workflow_steps/*` all exist.

## 3. Deduplicate `Document`'s "belongs to entity" validations

- **Where:** `app/models/document.rb:284-314` — `sender_belongs_to_entity`,
  `addressee_belongs_to_entity`, `department_belongs_to_entity`,
  `in_reply_to_belongs_to_entity`, `classification_node_belongs_to_entity`,
  `lead_user_belongs_to_entity` (reek: 6× `NilCheck`, same shape each time; flog:
  `Document#none` = 152.8, the highest class-body score in the app; file is 318 lines,
  the largest in `app/`)
- **Problem:** Six near-identical "if association present and its entity_id doesn't
  match self.entity_id, add an error" validations, hand-written each time. `flay`
  doesn't catch it (attribute names differ enough structurally) but it's the clearest
  duplication in the model layer.
- **Fix:** A small `validates_entity_scoped :sender, :addressee, :department, ...`
  class macro (a concern), generating the six validations from one implementation.
- **Risk:** Medium-high — `Document` is the central model of the app; get this wrong
  and every workflow breaks.
- **Effort:** Medium (~half day).
- **Spec safety net:** Good — `spec/models/document_spec.rb` exists and this app has a
  strict TDD history, so coverage on validations is likely solid. Confirm validation
  specs exist for all 6 associations before touching, add any missing ones first.

## 4. Simplify `PdfStamper` internals

- **Where:** `app/services/pdf_stamper.rb` (126 lines; flog: `draw_stamp` 44.4,
  `draw_signature_block` 37.9, `stamp_reference_and_logo` 29.7, `rasterized_logo_path`
  29.0; reek: `TooManyStatements` on 4 of its methods, `LongParameterList` on
  `draw_signature_block` (4 params), rescue variable named `e` ×3)
- **Problem:** The PDF-drawing methods do too much per method (measurements +
  drawing + fallback logic interleaved).
- **Fix:** Extract layout/measurement calculations from the actual `pdf.*` drawing
  calls; name rescue variables meaningfully.
- **Risk:** High in consequence, not likelihood — this is the SIGN-step signature
  stamping service ([[project_sign_step_electronic_signature]]), which is legally/
  audit-sensitive and has a strict "fail loudly, never silently" contract. Any
  refactor here needs the full spec suite green plus a manual visual check of a
  stamped PDF before merging.
- **Effort:** Medium.
- **Spec safety net:** `spec/services/pdf_stamper_spec.rb` exists — confirm it covers
  the failure-mode contract, not just the happy path, before refactoring.

## 5. Simplify `Templates::DocxTemplateProcessor#substitute_in_paragraph`

- **Where:** `app/services/templates/docx_template_processor.rb:59-83` (flog: 71.6,
  the single highest method score in the app; reek: `TooManyStatements` ~20,
  `NestedIterators` 2 deep, uncommunicative variable `i`)
- **Problem:** Span-splicing logic for `{{tag}}` substitution across DOCX XML runs is
  the densest method in the codebase.
- **Fix:** Extract the span-index bookkeeping (`node_groups`, span splitting) into a
  small collaborator object with named methods instead of inline array manipulation.
- **Risk:** Medium — subtle text-processing logic, easy to introduce off-by-one bugs.
- **Effort:** Medium.
- **Spec safety net:** `spec/services/templates/docx_template_processor_spec.rb`
  exists — check it has edge-case coverage (tags split across runs, adjacent tags)
  before refactoring, since that's exactly where regressions would hide.

## 6. Extract shared CRUD boilerplate for simple entity-scoped resources

- **Where:** `app/controllers/contacts_controller.rb`,
  `entities/circuit_templates_controller.rb`, `entities/departments_controller.rb`,
  `entities/document_templates_controller.rb`, `entities/email_templates_controller.rb`
  (flay: similar `defn`, mass=140)
- **Problem:** Five controllers share a near-identical action for simple
  entity-scoped CRUD resources.
- **Fix:** A shared concern for the common action, parameterized by resource name.
  Lower priority than #2 — this is boilerplate, not a hot path.
- **Risk:** Low-medium (5 files touched, but low-traffic admin-style resources).
- **Effort:** Medium (breadth, not depth).
- **Spec safety net:** Request specs likely exist per controller — verify each before
  starting.

## 7. `Wopi::FilesController` — memoize `@document.main_file`, name the repeated checks

- **Where:** `app/controllers/wopi/files_controller.rb` (158 lines, 16 reek warnings:
  `@document.main_file` called 4× in two different methods, `lock_matches?` and
  `policy.check_in?` each tested 3×, `MissingSafeMethod` on
  `authenticate_wopi_request!`)
- **Problem:** Repeated lookups and repeated conditionals across the WOPI lock/unlock/
  check-in protocol implementation.
- **Fix:** Memoize `main_file`, extract named predicate methods for the repeated
  conditionals.
- **Risk:** Medium-high in consequence — this is the live Collabora integration
  ([[project_wopi_collabora_editing]]), protocol-shaped code where subtle behavior
  changes are easy to miss and hard to test manually (needs an actual Collabora round
  trip, not just specs).
- **Effort:** Low-medium.
- **Spec safety net:** `spec/requests/wopi/*` and `spec/services/wopi/*` exist —
  good, but given the "hard to test manually" risk, treat this as lowest-urgency of
  the medium/high items; do it deliberately, not as a quick pass.

## Lower priority / defer

- **View-layer duplication** (flay hits #1, #3, #4, #6, #7, #9, #10, #12, #14) — mostly
  repeated `_form.html.erb` headers and breadcrumb blocks across ~10-15 views. Real
  duplication, but low risk and low per-instance value; high total effort because of
  the file count. Good candidate for a dedicated "extract shared form partials" pass
  later, not this session.
- **`NotificationMailer` data clump** (`document`, `user` passed to 7 methods) — minor,
  low risk, low value. Fold in opportunistically if touching this file for something
  else.
- **`Documents::AuditLogListComponent#description` / `dispatch_status_component.rb`**
  duplicate method (flay #13) — small, self-contained, easy but low-value.

## Explicitly not flagged

- File sizes are healthy: only `document.rb` (318) and `documents_controller.rb` (237)
  exceed 200 lines; nothing is egregiously oversized.
- RuboCop is clean (1 auto-correctable `Layout/EmptyLinesAroundClassBody` offense).
- No `flay` hits inside the service/organizer layer itself — the Phase 3 service-layer
  design ([[project_phase3_service_layer]]) is holding up well; duplication clusters
  are concentrated in controllers, policies, and views instead.

## Suggested order for this session

1. #1 (policy dedup) — smallest, safest, builds momentum.
2. #2 (organizer-response concern) — highest value, moderate effort.
3. #6 (CRUD concern) if time remains — same shape as #2, lower stakes.
4. Treat #3, #4, #5, #7 as separate follow-up sessions each — they touch
   higher-consequence code and deserve their own focused TDD cycle rather than being
   batched together.
