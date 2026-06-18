# Departments (Sub-Entity Document Scoping) — Implementation Plan

## Context

Today, every active member of an `Entity` (role `member` and above) can see **all** documents that belong to that entity, regardless of who created them. As entities grow, they are often organized into internal sub-units (e.g. "Finance & Administration", "Operations", "Sales"). The need is for documents to be scoped to the sub-unit that produced them, so that:

- A user always belongs to one (or more) sub-unit(s), and any document they author is tied to one of them.
- By default, a user only sees documents belonging to their own sub-unit(s) — not the whole entity.
- Some users legitimately need to see and act across **several** sub-units (e.g. a "Finance & Administration Director" overseeing two departments) without being promoted to a full entity administrator.
- At least one user per entity (today: `owner`/`admin`) keeps **unrestricted** visibility across the whole entity and all its sub-units — this is already true today and must not regress.

We discussed naming — "sous-entité" was rejected as inelegant — and settled on **`Department`**, which maps naturally onto the given example ("Finance & Administration Director" ≈ head of a Department).

Decisions already made with the user (not open for re-discussion):
1. **Naming**: `Department`, table `departments`, `belongs_to :entity`.
2. **Backfill**: existing documents get a default `"General"` Department per entity (flag `is_default`), created and backfilled via a rake task; `documents.department_id` becomes `NOT NULL` only after backfill completes everywhere.
3. **Scope**: only `Document` visibility/authorship is scoped by Department. `Contact` and `CircuitTemplate` stay entity-wide (shared), unaffected by this feature.
4. **Hierarchy**: flat — `Entity → Departments`, no nested sub-departments.
5. **Unrestricted roles**: `owner`/`admin` keep full-entity visibility, unchanged — this already matches current behavior and just needs explicit regression-proofing in specs.
6. **Restricted roles**: `member`/`guest` are limited to their assigned department(s).
7. **Multi-department membership**: a user can belong to several departments within one entity (many-to-many), with one marked `primary` (used as the default department when authoring a document).
8. **Direct access (`show?`)**: department restriction also applies to direct/URL access to a document, not just listings — with an explicit exception for users assigned as the **actor of a workflow step** on that document (so a cross-department approver can still act on documents routed to them).

---

## 1. Data Model

### `departments` table (new)

```ruby
create_table :departments do |t|
  t.references :entity, null: false, foreign_key: true
  t.string :name, null: false
  t.boolean :is_default, default: false, null: false
  t.timestamps
end
add_index :departments, [:entity_id, :name], unique: true
```

`is_default` flags the auto-created backfill bucket (avoids fragile `name == "General"` matching elsewhere; an admin can rename it later without breaking logic). Mirrors `Contact`/`CircuitTemplate`'s `uniqueness: { scope: :entity_id }` convention — no extra `code` column needed.

### `entity_user_departments` table (new — join model)

```ruby
create_table :entity_user_departments do |t|
  t.references :entity_user, null: false, foreign_key: true
  t.references :department, null: false, foreign_key: true
  t.boolean :primary, default: false, null: false
  t.timestamps
end
add_index :entity_user_departments, [:entity_user_id, :department_id], unique: true
add_index :entity_user_departments, :entity_user_id, unique: true, where: "primary",
          name: "index_one_primary_department_per_entity_user"
```

The partial unique index enforces "exactly one primary per member" at the DB level (Postgres-native, same idea as the existing unique index on `invitation_token`); model validation gives a friendly error message on top.

**Alternatives considered and rejected:**
- A single `department_id` + boolean `can_view_other_departments` on `EntityUser` — rejected because it can't express "exactly these two departments", only all-or-nothing, which conflates multi-department access with full entity access (already `owner`/`admin`'s job).
- An array column (`department_ids: bigint[]`) on `entity_users` — rejected: no room for the `primary` flag, no FK integrity, uglier Pundit `Scope` queries, and inconsistent with the codebase's existing pattern of real join models (`EntityUser` itself is exactly this pattern between `User` and `Entity`).

### `documents.department_id` (new column, staged rollout)

- Step 1 (schema): `add_reference :documents, :department, null: true, foreign_key: true` — nullable at first.
- Step 2 (data): backfill via rake task (see §7) — **not** embedded in a migration, since migrations referencing live model classes are fragile over time; a rake task runs once, intentionally, against the current codebase.
- Step 3 (schema): `change_column_null :documents, :department_id, false` — only after backfill is confirmed in that environment.

### Cross-entity consistency validations

- `EntityUserDepartment`: validate `department.entity_id == entity_user.entity_id`.
- `Document`: validate `department.entity_id == entity_id` (new private method `department_belongs_to_entity`, same pattern as the existing `sender`/`addressee` entity-consistency checks).

---

## 2. Models

**`app/models/department.rb`** (new)
```ruby
class Department < ApplicationRecord
  belongs_to :entity
  has_many :entity_user_departments, dependent: :destroy
  has_many :entity_users, through: :entity_user_departments
  has_many :documents, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :entity_id }

  scope :default, -> { where(is_default: true) }

  def default?
    is_default
  end
end
```
`dependent: :restrict_with_error` blocks deleting a department that still has documents (see §10).

**`app/models/entity_user_department.rb`** (new)
- `belongs_to :entity_user`, `belongs_to :department`
- `validates :department_id, uniqueness: { scope: :entity_user_id }`
- custom validation: department's entity must match entity_user's entity
- custom validation: only one `primary: true` row per `entity_user_id`

**`app/models/entity.rb`** — add `has_many :departments, dependent: :destroy`.

**`app/models/entity_user.rb`** — add:
```ruby
has_many :entity_user_departments, dependent: :destroy
has_many :departments, through: :entity_user_departments

def primary_department
  entity_user_departments.find_by(primary: true)&.department
end

def member_of?(department)
  department && departments.exists?(department.id)
end
```

**`app/models/document.rb`** — add `belongs_to :department` (presence enforced by default, no `optional: true`) plus the `department_belongs_to_entity` validation. No change to `PartyAssignable`/`party_in_entity?` — sender/addressee scoping stays entity-wide, per decision #3.

---

## 3. Authorization (Pundit)

**`app/policies/document_policy.rb`** — the core of this feature.

```ruby
def create?
  return false unless entity_staff?
  return true if entity_owner? || entity_admin?

  entity_user.departments.exists?
end

def show?
  return false unless entity_staff? || entity_guest?
  return true if entity_owner? || entity_admin?

  entity_user.member_of?(record.department) || record.workflow_steps.exists?(actor: user)
end
```
- `create?`: `owner`/`admin` can always author documents (even with zero department assignments). `member`/`guest` must belong to at least one department — satisfies "a user MUST belong to a Department for documents they author".
- `show?`: per decision #8, direct access is also restricted to department membership for `member`/`guest`, with an explicit carve-out for users assigned as the actor of one of the document's workflow steps (so a cross-department approver can still open and act on a document routed to them, even though it won't appear in their department-scoped listing).
- `update?`/`launch?`/`cancel?`/`approve?`/`reject?`: unchanged — these already gate on authorship or current-step actor, which is a strictly narrower condition than department membership, so no department check is needed there.

`Scope#resolve` — needs separate handling per entity_user row, since the same user can be `owner` of Entity A and `member` of Entity B simultaneously:
```ruby
class Scope < ApplicationPolicy::Scope
  def resolve
    scope.where(entity_id: unrestricted_entity_ids)
         .or(scope.where(entity_id: restricted_entity_ids, department_id: accessible_department_ids))
  end

  private

  def active_entity_users
    EntityUser.active.where(user: user)
  end

  def unrestricted_entity_ids
    active_entity_users.where(role: %w[owner admin]).select(:entity_id)
  end

  def restricted_entity_ids
    active_entity_users.where(role: %w[member guest]).select(:entity_id)
  end

  def accessible_department_ids
    EntityUserDepartment.where(entity_user_id: active_entity_users.where(role: %w[member guest]).select(:id))
                         .select(:department_id)
  end
end
```
A `member`/`guest` with zero department assignments simply sees nothing in that entity's document list — consistent with "must belong to a department".

**`app/policies/department_policy.rb`** (new) — CRUD on Department itself, mirrors `EntityPolicy`'s `manage_members?` pattern:
```ruby
def index? = entity_staff? || entity_guest?   # needed so any member can populate department pickers
def show?  = index?
def create? = entity_owner? || entity_admin?
def update? = entity_owner? || entity_admin?
def destroy? = (entity_owner? || entity_admin?) && !record.is_default? && record.documents.none?
```

---

## 4. Service Layer

Following the existing convention (organizers only for flows with real side effects — emails, multi-step writes, audit logging; plain CRUD for simple resources like `CircuitTemplate`):

- **Department CRUD**: plain controller actions, no organizer — same precedent as `Entities::CircuitTemplatesController`.
- **`app/services/entities/create_organizer.rb`**: add a new step `Actions::CreateDefaultDepartment` (new action, creates the entity's `"General"`/`is_default` department) so every newly-created entity always has at least one department, with no special-casing needed elsewhere. Do **not** auto-assign the owner to it — owners bypass department restriction entirely, so forcing an assignment adds noise without benefit.
- **`app/services/documents/create_organizer.rb`**: add a new step `Actions::ValidateDepartmentMembership` *before* `Actions::CreateDocument`, to give a clear user-facing error ("You are not a member of the selected department") rather than relying on the AR validation's generic entity-consistency message. `Actions::CreateDocument` itself needs no structural change — `department_id` simply flows through `document_params`.
- **`app/services/entities/invite_member_organizer.rb`**: add a new step `Actions::AssignDepartments` (after `CreateInvitation`, before `SendInvitationEmail`) that creates `entity_user_departments` rows from `department_ids`/`primary_department_id` params. No-op (zero iterations) for owner/admin invites where these are left blank.
- **New organizer `app/services/entities/update_member_departments_organizer.rb`**: handles "edit an existing member's department assignments" as a clean replace-the-set operation (diff add/remove, enforce exactly one primary) — this is a genuine multi-step concern, hence an organizer rather than ad hoc controller code.

---

## 5. Controllers & Routes

**`config/routes.rb`**: add `resources :departments, controller: "entities/departments"` inside the `resources :entities` block, and a `patch :update_departments` member route on `entity_users` (handled by `EntityUsersController#update_departments`) — chosen over a separate `entity_user_departments` REST resource because this is a bulk replace-the-set operation from one form, not a single create/destroy.

**`app/controllers/entities/departments_controller.rb`** (new) — standard CRUD, mirrors `Entities::CircuitTemplatesController` (index/new/create/edit/update/destroy via `current_entity.departments`), with `destroy` checking the return value of `@department.destroy` (false when `restrict_with_error` blocks it because documents still reference it).

**`app/controllers/concerns/entity_scoped.rb`** — add a memoized `current_entity_user` helper (the `EntityUser` record `authorize_entity_access!` already loads but discards), exposed via `helper_method`, so document forms and other views can query the current user's department memberships without an extra query.

**`app/controllers/entity_users_controller.rb`**:
- `create`: pass `department_ids:`/`primary_department_id:` through to `InviteMemberOrganizer`.
- new `update_departments` action calling `Entities::UpdateMemberDepartmentsOrganizer`.
- `entity_user_params` extended with `department_ids: []` and `primary_department_id`.

**`app/controllers/entities/settings_controller.rb`**: `show` loads `@departments = current_entity.departments.order(:name)` and eager-loads `entity_users.includes(:user, :departments)` to avoid N+1 in the member list.

**`app/controllers/documents_controller.rb`**: `document_params` permits `:department_id`. No other structural change — defaulting/hiding the picker is a view concern.

---

## 6. Views/UI

- **`app/views/documents/_form.html.erb`**: add a department `<select>` (visible only when `current_entity_user.departments.count > 1`; otherwise a hidden field defaulting to the user's single department, falling back to `current_entity.departments.default.first` for an owner/admin with no explicit assignment). Plain inline ERB — no new Stimulus component needed, since (unlike the existing party picker) there's no grouped-options/dynamic behavior involved.
- **`app/views/entities/settings/show.html.erb`**: add a "Departments" card (list + name, edit link gated on `policy(department).update?`, "Add department" gated on `policy(Department.new(entity: current_entity)).create?`). Extend the existing "Invite a member" form with a department multi-select + primary-department select (optional/ignored server-side for owner/admin invites).
- **`app/components/entities/member_row_component.rb`**: add department badge(s) next to the role badge, plus a "Manage departments" link for users with `manage_members?` — reuses the existing row rather than introducing a new component.
- **`app/views/entities/departments/`** (new): `new.html.erb`/`edit.html.erb`/`_form.html.erb`, single `name` field, mirroring `app/views/entities/circuit_templates/`.
- **`app/views/entity_users/edit_departments.html.erb`** (new): simple server-rendered form for the "manage an existing member's departments" flow (checkboxes + primary radio), paired with the `PATCH update_departments` route.

---

## 7. Migration / Backfill Plan

Ordered steps, deployed across two releases to avoid any window where `department_id` is required but not yet backfilled:

1. Migration: `CreateDepartments` (schema only).
2. Migration: `CreateEntityUserDepartments` (schema only, incl. partial unique index).
3. Migration: `AddDepartmentIdToDocuments` — nullable `add_reference`.
4. **Deploy** — schema + application code where `department_id` is not yet required.
5. **Rake task** `lib/tasks/departments.rake`:
   ```ruby
   namespace :departments do
     desc "Backfill a default Department per Entity and assign it to all existing Documents"
     task backfill: :environment do
       Entity.find_each do |entity|
         department = entity.departments.find_or_create_by!(name: "General") { |d| d.is_default = true }
         updated = entity.documents.where(department_id: nil).update_all(department_id: department.id)
         puts "Entity ##{entity.id} (#{entity.name}): #{updated} documents backfilled"
       end
     end
   end
   ```
   Idempotent (`find_or_create_by!` + `where(department_id: nil)`), uses `update_all` deliberately (bulk data fix, not model creation — no need to run document validations/callbacks). Run explicitly in each environment (dev/staging/prod) before the next step.
6. Migration: `AddNullConstraintToDocumentsDepartmentId` (`change_column_null :documents, :department_id, false`) — deployed only once step 5 is confirmed in that environment.

Fresh dev/test databases via `db:schema:load` are unaffected by the rake task — `schema.rb` will already reflect the final `NOT NULL` state, and `db/seeds.rb` (§8) creates departments directly for fresh data.

---

## 8. Seeds

Update `db/seeds.rb`:
- New helpers `add_department!(entity:, name:, is_default: false)` and `assign_department!(entity_user:, department:, primary: false)`, following the existing `find_or_create_by!` idiom.
- Give each of the 3 sample entities 2–3 departments (e.g. for Acme: "Sales", "Finance & Administration", "Operations").
- Update `add_document!` calls to pass the relevant `department:` (now required).
- Assign sample `member`-role users to a single department each (demonstrates the restricted case).
- Add one concrete "Finance & Admin Director" example: a `member`-role user assigned to **two** departments (e.g. "Finance & Administration" as primary, plus "Operations"), to demonstrate and let you manually verify the multi-department case end-to-end.

---

## 9. Testing Plan

**Model specs (new):** `spec/models/department_spec.rb` (uniqueness, `default?`, `restrict_with_error` on destroy with documents present), `spec/models/entity_user_department_spec.rb` (uniqueness, cross-entity validation, single-primary validation).

**Policy specs:**
- `spec/policies/department_policy_spec.rb` (new) — owner/admin can manage, member/guest cannot; `destroy?` false when department has documents or `is_default?`.
- `spec/policies/document_policy_spec.rb` (modify) — this is the most important spec update:
  - `#create?`: member with a department → permit; member with none → deny; owner/admin with none → still permit.
  - `#show?`: member viewing own-department document → permit; member viewing other-department document → deny; member viewing other-department document **where they're a workflow step actor** → permit; owner/admin → always permit.
  - `Scope`: member assigned to dept A sees only dept A's documents; member assigned to depts A+B sees both, not C; owner/admin see everything regardless of department (explicit regression test for decision #5); guest with no department sees nothing.

**Request specs:**
- `spec/requests/entities/departments_spec.rb` (new) — CRUD, auth (owner can / member cannot), destroy blocked while documents exist.
- `spec/requests/entity_users_spec.rb` (modify) — `create` passing department_ids creates the right `entity_user_departments` rows; `update_departments` action (manager allowed, others denied).
- `spec/requests/documents_spec.rb` (modify) — `create` without department membership rejected with a friendly message; member can create within their department; index/search respects department scoping for members but not owner/admin; direct `show` of another department's document denied for a plain member, allowed for an assigned workflow actor.

**Factories:**
- `spec/factories/departments.rb` (new), `spec/factories/entity_user_departments.rb` (new, with a `:primary` trait).
- `spec/factories/documents.rb` (modify) — `department { create(:department, entity: entity) }` since the column will be `NOT NULL`.
- `spec/factories/entity_users.rb` — optional convenience trait `:with_department` to reduce boilerplate across specs needing a department-assigned member.

---

## 10. Rollout / Edge Cases

- **CC recipients, shared links, workflow steps**: stay entity-scoped, unaffected by department — confirmed no changes needed (`CcRecipient`/`SharedLink` have no department concept, and `WorkflowStep#actor` can legitimately be any entity member regardless of department, e.g. cross-department sign-off). This is exactly why `show?`'s workflow-actor exception (§3) is needed — a workflow actor must still be able to open a document outside their own department(s) to act on it, even though it won't show up in their department-scoped document list.
- **Department deletion**: blocked at both the model layer (`dependent: :restrict_with_error`) and the policy layer (`destroy?` checks `record.documents.none?`) — defense in depth, friendlier UX (hide/disable the delete action) plus a DB-level safety net. The `is_default` department is never destroyable. No bulk "reassign documents then delete" tool in this first pass (admin reassigns documents individually via each document's edit form, which already gets a department field per §6, then deletes the now-empty department) — flagged as a reasonable future enhancement if departments turn out to be reorganized often.
- **Removing a member from an entity**: `has_many :entity_user_departments, dependent: :destroy` on `EntityUser` cleanly cascades, no orphaned join rows.
- **Suspending a member**: their `entity_user_departments` rows are left untouched (no cascade) — irrelevant since `DocumentPolicy::Scope` already filters through `EntityUser.active`, so a suspended member's stale department assignments are simply inert.

---

## Critical Files

- `app/policies/document_policy.rb` — the core authorization change (`create?`, `show?`, `Scope#resolve`); highest-risk, highest-value file in this plan.
- `db/migrate/..._create_departments.rb`, `..._create_entity_user_departments.rb`, `..._add_department_id_to_documents.rb`, `..._add_null_constraint_to_documents_department_id.rb` — schema foundation.
- `lib/tasks/departments.rake` — backfill task; must run cleanly in every environment before the NOT NULL migration is deployed there.
- `app/models/department.rb`, `app/models/entity_user_department.rb`, `app/models/entity_user.rb` (`primary_department`, `member_of?`) — membership logic that policies and views both depend on.
- `app/services/entities/invite_member_organizer.rb` (+ new `assign_departments.rb` action), `app/services/documents/create_organizer.rb` (+ new `validate_department_membership.rb` action), `app/services/entities/update_member_departments_organizer.rb` (new) — where department assignment and authorship validation get wired into existing workflows.
- `app/controllers/entities/departments_controller.rb` (new), `app/controllers/entity_users_controller.rb` (`update_departments`), `app/controllers/concerns/entity_scoped.rb` (`current_entity_user` helper).

---

## Verification

1. **Unit/policy/request specs** (§9) — run `bundle exec rspec spec/models/department_spec.rb spec/models/entity_user_department_spec.rb spec/policies/department_policy_spec.rb spec/policies/document_policy_spec.rb spec/requests/entities/departments_spec.rb spec/requests/entity_users_spec.rb spec/requests/documents_spec.rb`, then the full suite (`bundle exec rspec`) to catch regressions (e.g. existing document specs/factories needing the now-required `department`).
2. **RuboCop** — `bundle exec rubocop` on all new/modified files, matching the project's "RuboCop clean" standard.
3. **Manual / system walkthrough** (via the `run` skill or a local server):
   - As an entity owner: create 2 departments, invite a `member` assigned to only one of them, invite a second `member` assigned to both (the "Finance & Admin Director" case).
   - As the single-department member: create a document, confirm it only appears in their own document list, and confirm visiting another department's document URL directly is denied.
   - As the two-department member: confirm documents from both departments appear in their list and can be created in either.
   - As the owner/admin: confirm full visibility across all departments is unchanged.
   - Place the single-department member as a workflow-step actor on a document from a department they don't belong to, and confirm they can open (`show`) and act on it via the workflow action, even though it's absent from their listing.
4. **Backfill rake task dry run** on a copy of production-like seeded data (`bin/rails departments:backfill`) to confirm idempotency and correct default-department creation before relying on it in a real deploy.
