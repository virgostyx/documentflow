# Incoming Mail Reply Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let staff link an incoming mail, at routing time, to the outgoing document it replies to — so that original document leaves its creator's "Waiting" tab once the reply is filed, and both documents show each other in the existing "Document chain" UI.

**Architecture:** Reuse `Document#in_reply_to_id` (no migration). A new `Document.repliable_by(sender)` scope feeds a plain `<select>` on the existing incoming-mail routing form. Fix two latent bugs this surfaces: `waiting_for`/`todo_for` currently test AASM `status: "finalized"` to detect an answered original, which an incoming document (routed, never AASM-finalized) can never satisfy; and the "Document chain" card (`@document_chain` + `Documents::ThreadComponent`) is built/linked outgoing-only, so it would silently drop or mislink an incoming reply.

**Tech Stack:** Rails 8, RSpec (model/request/component/system specs), ViewComponent, LightService-style organizer/action objects, Capybara + `js: true` for system specs.

## Global Constraints

- No database migration — reuse the existing `in_reply_to_id` column and its associations (`belongs_to :in_reply_to`, `has_many :replies`).
- All UI text (labels, messages) must be in English.
- Follow TDD: write the failing test before the implementation for every step below.
- Every model/scope/controller change must not alter behavior for existing, already-tested flows — run the full affected spec file after each change, not just the new examples.
- Match existing code style exactly: `Document.settled`/`Document.finalized` explicit-class-prefix style inside scope blocks (this codebase does not extract shared private scope helpers — see `waiting_for`/`todo_for`), `FloatingLabelsRails::FormBuilder` for form fields, `render_inline`/`type: :component` for ViewComponent specs, `Capybara.using_session`/`sign_in_via_form` for system specs.

Reference spec: `docs/dev/09_Incoming_Mail_Reply_Link_Feature_Plan.md`.

---

### Task 1: Fix `waiting_for`/`todo_for` to recognize a routed incoming reply as "answered"

**Files:**
- Modify: `app/models/document.rb:66` (inside `todo_for`), `app/models/document.rb:84` (inside `waiting_for`)
- Test: `spec/models/document_spec.rb` (`.waiting_for` describe block, currently lines 810-883)

**Interfaces:**
- Consumes: nothing new — pure refactor of an existing private query inside two existing scopes.
- Produces: `Document.waiting_for(user)` and `Document.todo_for(user)` now exclude an original once *any* settled document (outgoing-finalized or incoming-routed) links to it via `in_reply_to_id`, not just an outgoing-finalized one. This is what Task 2/3's new linking feature relies on to actually clear "Waiting".

- [ ] **Step 1: Write the failing tests**

Add these two examples inside the existing `describe ".waiting_for" do ... end` block in `spec/models/document_spec.rb` (e.g. right after the existing "excludes a document when only one of several replies is finalized" example, around line 855):

```ruby
    it "excludes an outgoing document once a routed incoming reply is linked to it" do
      user = create(:user)
      original = create(:document, :expecting_response, entity: entity, created_by: user)
      create(:document, :incoming, :routed, entity: entity, in_reply_to: original)

      expect(Document.waiting_for(user)).to be_empty
    end

    it "keeps an outgoing document in the waiting list while its linked incoming reply is not yet routed" do
      user = create(:user)
      original = create(:document, :expecting_response, entity: entity, created_by: user)
      create(:document, :incoming, entity: entity, in_reply_to: original)

      expect(Document.waiting_for(user)).to contain_exactly(original)
    end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/models/document_spec.rb -e ".waiting_for"`
Expected: the two new examples FAIL (the routed incoming reply does not clear `original` from `waiting_for`, because `Document.finalized` never matches an incoming document). All pre-existing examples in this block still PASS.

- [ ] **Step 3: Fix the two scopes**

In `app/models/document.rb`, change the `todo_for` scope (currently):

```ruby
  scope :todo_for, ->(user) {
    replied_document_ids = Document.finalized
                                    .where(created_by_id: user.id)
                                    .where.not(in_reply_to_id: nil)
                                    .select(:in_reply_to_id)

    where(addressee_type: "User", addressee_id: user.id, expects_response: true)
      .where.not(id: replied_document_ids)
  }
```

to:

```ruby
  scope :todo_for, ->(user) {
    replied_document_ids = Document.settled
                                    .where(created_by_id: user.id)
                                    .where.not(in_reply_to_id: nil)
                                    .select(:in_reply_to_id)

    where(addressee_type: "User", addressee_id: user.id, expects_response: true)
      .where.not(id: replied_document_ids)
  }
```

And the `waiting_for` scope (currently):

```ruby
  scope :waiting_for, ->(user) {
    replied_document_ids = Document.finalized.where.not(in_reply_to_id: nil).select(:in_reply_to_id)

    where(
      "(documents.direction = 'outgoing' AND documents.created_by_id = :user_id) " \
      "OR (documents.direction = 'incoming' AND documents.lead_user_id = :user_id)",
      user_id: user.id
    ).where(expects_response: true).where.not(id: replied_document_ids)
  }
```

to:

```ruby
  scope :waiting_for, ->(user) {
    replied_document_ids = Document.settled.where.not(in_reply_to_id: nil).select(:in_reply_to_id)

    where(
      "(documents.direction = 'outgoing' AND documents.created_by_id = :user_id) " \
      "OR (documents.direction = 'incoming' AND documents.lead_user_id = :user_id)",
      user_id: user.id
    ).where(expects_response: true).where.not(id: replied_document_ids)
  }
```

(Only `Document.finalized` → `Document.settled` changes in each scope — nothing else.)

- [ ] **Step 4: Run the full spec file to verify everything passes**

Run: `bundle exec rspec spec/models/document_spec.rb`
Expected: PASS, including every pre-existing `.todo_for` and `.waiting_for` example (this confirms the swap is behavior-preserving for the outgoing-only case, since today nothing ever sets `in_reply_to_id` on an incoming document, so `Document.finalized` and `Document.settled` select the exact same rows for every scenario that existed before this change).

- [ ] **Step 5: Commit**

```bash
git add app/models/document.rb spec/models/document_spec.rb
git commit -m "Recognize a routed incoming reply as answering an outgoing document

waiting_for/todo_for excluded an already-answered original via
Document.finalized, which an incoming document can never satisfy (it
uses routed_at, not the finalized AASM status). Swap to Document.settled,
which already handles this outgoing/incoming distinction."
```

---

### Task 2: Add `Document.repliable_by(sender)` scope

**Files:**
- Modify: `app/models/document.rb` (new scope, placed after the `settled` scope, currently ending at line 116, before `in_classification_node`)
- Test: `spec/models/document_spec.rb` (new `describe ".repliable_by"` block, placed after the `.settled` describe block, currently ending around line 1063)

**Interfaces:**
- Consumes: `Document.settled`, `Document.outgoing` (existing scopes, document.rb:103-116).
- Produces: `Document.repliable_by(party)` — an `ActiveRecord::Relation` of outgoing, settled, `expects_response: true` documents addressed to `party` that don't already have a settled reply linked. Used by Task 3's routing form to populate the "Replies to" `<select>`. `party` is any `Party` (e.g. `Contact`) record — anything with a `.class.name`/`.id` usable as a polymorphic `addressee`.

- [ ] **Step 1: Write the failing tests**

Add this new block in `spec/models/document_spec.rb`, right after the `describe ".settled" do ... end` block:

```ruby
  describe ".repliable_by" do
    it "returns an outgoing, settled document addressed to the given party and expecting a response" do
      party = create(:contact, entity: entity)
      original = create(:document, :finalized, :expecting_response, entity: entity, addressee: party)

      expect(Document.repliable_by(party)).to contain_exactly(original)
    end

    it "excludes a document that is not yet settled (still draft)" do
      party = create(:contact, entity: entity)
      create(:document, :expecting_response, entity: entity, addressee: party)

      expect(Document.repliable_by(party)).to be_empty
    end

    it "excludes a document that does not expect a response" do
      party = create(:contact, entity: entity)
      create(:document, :finalized, entity: entity, addressee: party)

      expect(Document.repliable_by(party)).to be_empty
    end

    it "excludes a document addressed to a different party" do
      party = create(:contact, entity: entity)
      other_party = create(:contact, entity: entity)
      create(:document, :finalized, :expecting_response, entity: entity, addressee: other_party)

      expect(Document.repliable_by(party)).to be_empty
    end

    it "excludes an incoming document even if it otherwise matches" do
      party = create(:contact, entity: entity)
      create(:document, :incoming, :routed, :expecting_response, entity: entity, addressee: party)

      expect(Document.repliable_by(party)).to be_empty
    end

    it "excludes a document that already has a settled reply linked" do
      party = create(:contact, entity: entity)
      original = create(:document, :finalized, :expecting_response, entity: entity, addressee: party)
      create(:document, :incoming, :routed, entity: entity, in_reply_to: original)

      expect(Document.repliable_by(party)).to be_empty
    end

    it "keeps a document when its only reply is not yet settled" do
      party = create(:contact, entity: entity)
      original = create(:document, :finalized, :expecting_response, entity: entity, addressee: party)
      create(:document, :incoming, entity: entity, in_reply_to: original)

      expect(Document.repliable_by(party)).to contain_exactly(original)
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/models/document_spec.rb -e ".repliable_by"`
Expected: FAIL with `NoMethodError: undefined method 'repliable_by' for Document`.

- [ ] **Step 3: Implement the scope**

In `app/models/document.rb`, add this scope immediately after the `settled` scope (after the closing `}` at line 116, before `scope :in_classification_node`):

```ruby
  scope :repliable_by, ->(sender) {
    outgoing.settled
            .where(addressee_type: sender.class.name, addressee_id: sender.id, expects_response: true)
            .where.not(id: Document.settled.where.not(in_reply_to_id: nil).select(:in_reply_to_id))
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/models/document_spec.rb -e ".repliable_by"`
Expected: PASS, all 7 examples.

- [ ] **Step 5: Commit**

```bash
git add app/models/document.rb spec/models/document_spec.rb
git commit -m "Add Document.repliable_by scope for linking an incoming mail to its original"
```

---

### Task 3: Wire the link into the incoming-mail routing flow

**Files:**
- Modify: `app/controllers/incoming_mails_controller.rb` (`routing_params`)
- Modify: `app/services/incoming_mails/actions/route_incoming_mail.rb`
- Modify: `app/views/incoming_mails/_route_form.html.erb`
- Test: `spec/services/incoming_mails/route_organizer_spec.rb`
- Test: `spec/requests/incoming_mails_spec.rb`

**Interfaces:**
- Consumes: `Document.repliable_by` (Task 2), `IncomingMails::RouteOrganizer.call(document:, current_user:, routing_params:)` (existing organizer, unchanged interface — only the permitted keys inside `routing_params` grow).
- Produces: routing a mail with `in_reply_to_id` present in `routing_params` persists `document.in_reply_to_id` and records it in the audit log's `audit_changes`. Routing without it behaves exactly as before.

- [ ] **Step 1: Write the failing service-level tests**

In `spec/services/incoming_mails/route_organizer_spec.rb`, add this new context inside `describe ".call" do context "with valid params" do ... end` (as a sibling to the existing `it` examples there):

```ruby
      context "when routing_params includes in_reply_to_id" do
        let(:original) { create(:document, :finalized, :expecting_response, entity: entity, department: department) }
        let(:routing_params) do
          { action_user_id: action_user.id, expects_response: false, in_reply_to_id: original.id, info_user_ids: [ "" ] }
        end

        it "persists the link to the original document" do
          described_class.call(document: document, current_user: lead, routing_params: routing_params)

          expect(document.reload.in_reply_to).to eq(original)
        end

        it "clears the original document from its creator's waiting list" do
          creator = original.created_by
          described_class.call(document: document, current_user: lead, routing_params: routing_params)

          expect(Document.waiting_for(creator)).not_to include(original)
        end
      end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/services/incoming_mails/route_organizer_spec.rb`
Expected: the two new examples FAIL (`in_reply_to` stays `nil` — `routing_params[:in_reply_to_id]` is currently silently ignored by `RouteIncomingMail`). Every pre-existing example in the file still PASSES.

- [ ] **Step 3: Permit the new param**

In `app/controllers/incoming_mails_controller.rb`, change:

```ruby
  def routing_params
    params.require(:document).permit(:action_user_id, :routing_message, :expects_response, :response_deadline, info_user_ids: [])
  end
```

to:

```ruby
  def routing_params
    params.require(:document).permit(:action_user_id, :routing_message, :expects_response, :response_deadline, :in_reply_to_id, info_user_ids: [])
  end
```

- [ ] **Step 4: Persist and audit the link**

In `app/services/incoming_mails/actions/route_incoming_mail.rb`, change:

```ruby
      executed do |ctx|
        document = ctx.document

        if document.update(
          addressee_type: "User",
          addressee_id: ctx.routing_params[:action_user_id],
          routing_message: ctx.routing_params[:routing_message],
          expects_response: ctx.routing_params[:expects_response],
          response_deadline: ctx.routing_params[:response_deadline],
          routed_at: Time.current
        )
          ctx.document = document
          ctx[:user] = ctx.current_user
          ctx[:auditable] = document
          ctx[:action] = "route"
          ctx[:audit_changes] = { action_user_id: document.addressee_id, expects_response: document.expects_response }
        else
          fail_with!(ctx, document.errors.full_messages.to_sentence, :validation_error)
        end
      end
```

to:

```ruby
      executed do |ctx|
        document = ctx.document

        if document.update(
          addressee_type: "User",
          addressee_id: ctx.routing_params[:action_user_id],
          routing_message: ctx.routing_params[:routing_message],
          expects_response: ctx.routing_params[:expects_response],
          response_deadline: ctx.routing_params[:response_deadline],
          in_reply_to_id: ctx.routing_params[:in_reply_to_id],
          routed_at: Time.current
        )
          ctx.document = document
          ctx[:user] = ctx.current_user
          ctx[:auditable] = document
          ctx[:action] = "route"
          ctx[:audit_changes] = {
            action_user_id: document.addressee_id,
            expects_response: document.expects_response,
            in_reply_to_id: document.in_reply_to_id
          }
        else
          fail_with!(ctx, document.errors.full_messages.to_sentence, :validation_error)
        end
      end
```

- [ ] **Step 5: Run the service tests to verify they pass**

Run: `bundle exec rspec spec/services/incoming_mails/route_organizer_spec.rb`
Expected: PASS, all examples.

- [ ] **Step 6: Write the failing request-level tests**

In `spec/requests/incoming_mails_spec.rb`:

Inside `describe "GET /entities/:entity_id/incoming_mails/:id/route_form" do context "as the lead" do ... end`, add:

```ruby
      context "when a repliable original document exists" do
        let!(:original) { create(:document, :finalized, :expecting_response, entity: entity, department: department, addressee: document.sender) }

        it "shows the Replies to field with the candidate" do
          get route_form_entity_incoming_mail_path(entity, document)

          expect(response.body).to include("Replies to")
          expect(response.body).to include(original.display_number)
        end
      end
```

Inside `describe "PATCH /entities/:entity_id/incoming_mails/:id/route" do context "as the lead" do ... end`, add:

```ruby
      context "when linking to an original document" do
        let(:original) { create(:document, :finalized, :expecting_response, entity: entity, department: department) }
        let(:params) do
          { document: { action_user_id: user.id, expects_response: "0", in_reply_to_id: original.id } }
        end

        it "persists the link to the original document" do
          patch route_entity_incoming_mail_path(entity, document), params: params

          expect(document.reload.in_reply_to).to eq(original)
        end
      end
```

- [ ] **Step 7: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/incoming_mails_spec.rb`
Expected: the two new examples FAIL (the form has no "Replies to" field yet, and the PATCH doesn't persist the link since the view isn't submitting it and — actually the PATCH test hits the controller/action directly, so re-check: it should already pass after Step 3-4 above, since Step 6 tests the *controller* param permission and action persistence, not the *view*). Run this after Step 4 (not before) if you want it green already; regardless, run it now and confirm: the `route_form` GET example FAILS (no field in the view yet), the `route` PATCH example should already PASS (controller/action already fixed in Steps 3-4).

- [ ] **Step 8: Add the field to the routing form**

In `app/views/incoming_mails/_route_form.html.erb`, insert this block immediately after the `action_user_id` floating_select (after line 11, before the `routing_message` floating_text_area):

```erb
  <% repliable_documents = current_entity.documents.repliable_by(document.sender) %>
  <% if repliable_documents.any? %>
    <%= f.floating_select :in_reply_to_id, repliable_documents.map { |d| [ "#{d.display_number} — #{d.subject}", d.id ] },
          { selected: document.in_reply_to_id, include_blank: "Not a reply to an existing document" },
          { label: "Replies to (optional)" } %>
  <% end %>
```

- [ ] **Step 9: Run the request tests to verify they pass**

Run: `bundle exec rspec spec/requests/incoming_mails_spec.rb`
Expected: PASS, all examples including the two new ones.

- [ ] **Step 10: Commit**

```bash
git add app/controllers/incoming_mails_controller.rb app/services/incoming_mails/actions/route_incoming_mail.rb app/views/incoming_mails/_route_form.html.erb spec/services/incoming_mails/route_organizer_spec.rb spec/requests/incoming_mails_spec.rb
git commit -m "Let staff link an incoming mail to the outgoing document it replies to

Adds an optional 'Replies to' field to the routing form, populated from
Document.repliable_by. Persists to the existing in_reply_to_id column."
```

---

### Task 4: Include routed incoming mail in a document's "Document chain"

**Files:**
- Modify: `app/controllers/documents_controller.rb:57-62` (`show` action)
- Test: `spec/requests/documents_spec.rb` (new context inside the existing "when the document is part of a reply chain" context, currently lines 1013-1029)

**Interfaces:**
- Consumes: `merged_base_scope` (existing private method, `documents_controller.rb:169-171`, already used by `todo`/`waiting`/`info`).
- Produces: `@document_chain` (instance variable read by `documents/show.html.erb` and passed to `Documents::ThreadComponent`) now includes incoming documents that are part of the thread, not just outgoing ones.

- [ ] **Step 1: Write the failing test**

In `spec/requests/documents_spec.rb`, inside the existing `context "when the document is part of a reply chain" do ... end` block (currently lines 1013-1029), add a sibling context:

```ruby
      context "when the document is part of a reply chain that includes a routed incoming mail" do
        let!(:incoming_reply) do
          create(:document, :incoming, :routed, entity: entity, department: department,
            in_reply_to: document, subject: "Re: original (their reply)")
        end

        it "includes the incoming mail in the document chain on the original document's page" do
          get entity_document_path(entity, document)

          expect(response.body).to include("Document chain")
          expect(response.body).to include(incoming_reply.display_number)
        end
      end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/requests/documents_spec.rb -e "reply chain that includes a routed incoming mail"`
Expected: FAIL — `incoming_reply.display_number` is missing from the response body, because `@document_chain` is built from `base_scope`, which is `.outgoing`-only and silently drops the incoming document.

- [ ] **Step 3: Fix the controller**

In `app/controllers/documents_controller.rb`, change:

```ruby
  def show
    authorize @document
    @document_chain = base_scope.where(id: @document.thread.map(&:id))
                                 .includes(:sender, :addressee)
                                 .sort_by { |doc| [ doc.document_date, doc.created_at ] }
  end
```

to:

```ruby
  def show
    authorize @document
    @document_chain = merged_base_scope.where(id: @document.thread.map(&:id))
                                        .includes(:sender, :addressee)
                                        .sort_by { |doc| [ doc.document_date, doc.created_at ] }
  end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/requests/documents_spec.rb -e "reply chain"`
Expected: PASS, both the new example and the two pre-existing "shows the document chain on the original/reply" examples (lines 1016-1028).

- [ ] **Step 5: Run the full file to check for regressions**

Run: `bundle exec rspec spec/requests/documents_spec.rb`
Expected: PASS, no regressions (every other `@document_chain` scenario in this file was already outgoing-only, so `merged_base_scope` returns identical rows to `base_scope` for those).

- [ ] **Step 6: Commit**

```bash
git add app/controllers/documents_controller.rb spec/requests/documents_spec.rb
git commit -m "Include routed incoming mail in a document's reply chain view"
```

---

### Task 5: Fix `Documents::ThreadComponent` to link incoming documents correctly

**Files:**
- Modify: `app/components/documents/thread_component.rb`
- Modify: `app/components/documents/thread_component.html.erb`
- Test: Create `spec/components/documents/thread_component_spec.rb`

**Interfaces:**
- Consumes: `Document#incoming?` (existing, document.rb:194-196).
- Produces: `Documents::ThreadComponent.new(documents:, current_document:)` (unchanged public interface) now links each non-current document to the correct show page — `entity_incoming_mail_path` for incoming, `entity_document_path` for outgoing.

- [ ] **Step 1: Write the failing tests**

Create `spec/components/documents/thread_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::ThreadComponent, type: :component do
  let(:entity) { create(:entity) }
  let(:department) { create(:department, entity: entity) }

  it "links an outgoing document in the chain to its show page" do
    original = create(:document, :finalized, entity: entity, department: department)
    reply = create(:document, :finalized, entity: entity, department: department, in_reply_to: original)
    rendered = render_inline(described_class.new(documents: [ original, reply ], current_document: original))

    expected_path = Rails.application.routes.url_helpers.entity_document_path(entity, reply)
    expect(rendered).to have_css("a[href='#{expected_path}']", text: reply.display_number)
  end

  it "links an incoming document in the chain to its incoming-mail show page" do
    original = create(:document, :finalized, entity: entity, department: department)
    incoming_reply = create(:document, :incoming, :routed, entity: entity, department: department, in_reply_to: original)
    rendered = render_inline(described_class.new(documents: [ original, incoming_reply ], current_document: original))

    expected_path = Rails.application.routes.url_helpers.entity_incoming_mail_path(entity, incoming_reply)
    expect(rendered).to have_css("a[href='#{expected_path}']", text: incoming_reply.display_number)
  end

  it "marks the current document instead of linking it" do
    original = create(:document, :finalized, entity: entity, department: department)
    rendered = render_inline(described_class.new(documents: [ original ], current_document: original))

    expect(rendered).to have_text("Current")
    expect(rendered).not_to have_css("a", text: original.display_number)
  end
end
```

- [ ] **Step 2: Run the tests to verify the incoming-document case fails**

Run: `bundle exec rspec spec/components/documents/thread_component_spec.rb`
Expected: the "links an incoming document..." example FAILS (it currently renders `entity_document_path`, the wrong route, so the expected `href` isn't found). The other two examples PASS already.

- [ ] **Step 3: Add the path helper to the component**

In `app/components/documents/thread_component.rb`, change:

```ruby
module Documents
  class ThreadComponent < ViewComponent::Base
    def initialize(documents:, current_document:)
      @documents = documents
      @current_document = current_document
    end

    private

    attr_reader :documents, :current_document

    def current?(document)
      document == current_document
    end
  end
end
```

to:

```ruby
module Documents
  class ThreadComponent < ViewComponent::Base
    def initialize(documents:, current_document:)
      @documents = documents
      @current_document = current_document
    end

    private

    attr_reader :documents, :current_document

    def current?(document)
      document == current_document
    end

    def document_path_for(document)
      document.incoming? ? entity_incoming_mail_path(document.entity, document) : entity_document_path(document.entity, document)
    end
  end
end
```

- [ ] **Step 4: Use it in the template**

In `app/components/documents/thread_component.html.erb`, change:

```erb
            <%= link_to document.display_number, entity_document_path(document.entity, document), class: "font-mono text-primary-700 hover:text-primary-800" %>
```

to:

```erb
            <%= link_to document.display_number, document_path_for(document), class: "font-mono text-primary-700 hover:text-primary-800" %>
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bundle exec rspec spec/components/documents/thread_component_spec.rb`
Expected: PASS, all 3 examples.

- [ ] **Step 6: Commit**

```bash
git add app/components/documents/thread_component.rb app/components/documents/thread_component.html.erb spec/components/documents/thread_component_spec.rb
git commit -m "Link incoming documents in the Document chain card to their own show page"
```

---

### Task 6: End-to-end system spec

**Files:**
- Create: `spec/system/incoming_mail_reply_link_spec.rb`

**Interfaces:**
- Consumes: everything from Tasks 1-5 — this is a pure black-box UI test, no new production code.
- Produces: nothing consumed downstream; this is the final verification task.

- [ ] **Step 1: Write the system spec**

Create `spec/system/incoming_mail_reply_link_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Linking an incoming mail reply to its original document", type: :system, js: true do
  let(:entity) { create(:entity, name: "Acme Corp") }
  let(:department) { create(:department, entity: entity, name: "Finance") }
  let(:creator) { create(:user) }
  let(:lead) { create(:user) }
  let!(:external_party) { create(:contact, entity: entity, first_name: "Jane", last_name: "Doe") }
  let!(:original) do
    create(:document, :finalized, :expecting_response, entity: entity, department: department,
      created_by: creator, addressee: external_party, subject: "Request for tax documents")
  end

  before do
    [ creator, lead ].each do |member|
      eu = create(:entity_user, entity: entity, user: member, role: "member", status: "active")
      create(:entity_user_department, :primary, entity_user: eu, department: department)
    end
  end

  it "clears the original from Waiting once the reply is registered and linked at routing" do
    Capybara.using_session(:creator) do
      sign_in_via_form(creator)
      visit waiting_entity_documents_path(entity)
      expect(page).to have_content("Request for tax documents")
    end

    Capybara.using_session(:lead) do
      sign_in_via_form(lead)

      visit new_entity_incoming_mail_path(entity)
      fill_in "Subject", with: "Re: Request for tax documents"
      fill_in "Document date", with: Date.current
      select "Jane Doe", from: "Sender"
      select lead.display_name, from: "Assign to"
      click_button "Register mail"
      expect(page).to have_content("Incoming mail registered successfully")

      click_link "Route this mail"
      within("dialog") do
        select lead.display_name, from: "Assign for action"
        select "#{original.display_number} — Request for tax documents", from: "Replies to (optional)"
        click_button "Route mail"
      end
      expect(page).to have_content("Mail routed successfully")

      expect(page).to have_content("Document chain")
      expect(page).to have_content(original.display_number)
    end

    Capybara.using_session(:creator) do
      sign_in_via_form(creator)
      visit waiting_entity_documents_path(entity)
      expect(page).not_to have_content("Request for tax documents")

      visit entity_document_path(entity, original)
      expect(page).to have_content("Document chain")
      expect(page).to have_content("Re: Request for tax documents")
    end
  end
end
```

- [ ] **Step 2: Run it and confirm it passes**

Run: `bundle exec rspec spec/system/incoming_mail_reply_link_spec.rb`
Expected: PASS. If it fails, re-check (in order): the "Replies to (optional)" option text must match `"#{original.display_number} — Request for tax documents"` exactly (an em dash `—`, not a hyphen, per Task 3 Step 8) — print `original.display_number` if unsure by temporarily adding `puts` in the spec; confirm Task 1-5 commits are all present (`git log --oneline -6`).

- [ ] **Step 3: Run the full suite for a final regression check**

Run: `bundle exec rspec`
Expected: PASS, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add spec/system/incoming_mail_reply_link_spec.rb
git commit -m "Add end-to-end system spec for linking an incoming mail reply"
```

---

## Post-implementation

Update `docs/dev/09_Incoming_Mail_Reply_Link_Feature_Plan.md`'s Status line from "DESIGNED, not yet implemented" to "IMPLEMENTED (<date>)", matching the convention used by every other file in `docs/dev/` (e.g. `docs/dev/07_Email_Archive_Ingestion_Feature_Plan.md:3`).
