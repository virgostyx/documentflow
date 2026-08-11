# Linking an Incoming Mail Reply to its Original Document — Design

Status: IMPLEMENTED (2026-08-11).

## 1. Concept

An outgoing document sent to an **external** addressee with
`expects_response: true` shows up in its creator's "Waiting" tab
(`Document.waiting_for`, document.rb:83-91) and stays there until answered.
Today there is no way for it to leave that tab: the only thing that clears an
entry is a new *finalized* document whose `in_reply_to_id` points back at it,
and the only UI path that sets `in_reply_to_id` is the "Reply" button
(`Documents::RowComponent`), which only ever appears when the current user
*is* the addressee (`Document#awaiting_response_from?`, document.rb:186-188)
— impossible when the addressee is an external `Party`.

When the external reply physically arrives, it's registered as an
**incoming mail** (`IncomingMails::RegisterOrganizer`) and later routed to an
internal assignee (`IncomingMails::RouteOrganizer`). Neither step currently
offers any way to say "this incoming mail is the reply to that outgoing
document" — so the original silently rots in Waiting forever, even after the
answer has been received and filed.

This feature adds that link, at routing time, reusing the existing
`in_reply_to_id` column and the scopes/UI already built around it.

## 2. Decisions validated with the user

| Question | Decision |
|---|---|
| When is the link established? | **At routing** (`IncomingMailsController#route`), not at initial registration. The `lead_user` who routes the mail has actually read its content by then; the person registering it (often front desk) usually hasn't. |
| How is the candidate original found? | **A plain `<select>`**, not a search/autocomplete widget. Filtered server-side to outgoing, settled, `expects_response: true` documents addressed to the same external `Party` as the incoming mail's sender, that don't already have a reply. Scoped enough to stay short — no need for a search component. |
| Should the link surface anywhere visible? | **Yes** — reuse the existing "Document chain" card (`Documents::ThreadComponent`) on `documents/show`, rather than building a new badge. See §5: it already does almost exactly this, for outgoing-only threads. |
| New DB column? | **No.** `in_reply_to_id` already exists and already means "this document answers that document" via the existing `Reply` button flow. Introducing a second field would duplicate the `todo_for`/`waiting_for` exclusion logic for no benefit — same concept, same column. |

## 3. Data model

No migration. `Document#in_reply_to_id` / `belongs_to :in_reply_to` /
`has_many :replies` (document.rb:27-31) are reused as-is.
`validates_entity_scoped :department, :in_reply_to` (document.rb:52) already
guards against cross-entity links.

New scope on `Document`:

```ruby
scope :repliable_by, ->(sender) {
  outgoing.settled
          .where(addressee_type: sender.class.name, addressee_id: sender.id, expects_response: true)
          .where.not(id: Document.settled.where.not(in_reply_to_id: nil).select(:in_reply_to_id))
}
```

Called as `document.entity.documents.repliable_by(document.sender)` from the
routing form, where `document` is the incoming mail being routed and
`document.sender` is the external `Party` who wrote it.

## 4. UI — routing form

`app/views/incoming_mails/_route_form.html.erb` gains an optional field,
placed near `action_user_id`:

```erb
<% candidates = current_entity.documents.repliable_by(document.sender) %>
<% if candidates.any? %>
  <%= f.floating_select :in_reply_to_id, candidates.map { |d| [ "#{d.display_number} — #{d.subject}", d.id ] },
        { selected: document.in_reply_to_id, include_blank: "Not a reply to an existing document" },
        { label: "Replies to (optional)" } %>
<% end %>
```

The field is hidden entirely when there are no candidates (the common case:
most incoming mail isn't a reply to anything we sent).

## 5. Backend

- `IncomingMailsController#routing_params` (incoming_mails_controller.rb):
  add `:in_reply_to_id` to the permitted list.
- `IncomingMails::Actions::RouteIncomingMail` (route_incoming_mail.rb:12-19):
  add `in_reply_to_id: ctx.routing_params[:in_reply_to_id].presence` to the
  `document.update(...)` call, and add it to `ctx[:audit_changes]` alongside
  the existing `action_user_id`/`expects_response` entries — same audit
  pattern already in place.

## 6. Existing bugs this feature exposes (fixed as part of this work)

**Bug A — `waiting_for`/`todo_for` would never notice the link.**
Both scopes exclude "already answered" originals via:

```ruby
Document.finalized.where.not(in_reply_to_id: nil).select(:in_reply_to_id)   # document.rb:66-68 (todo_for), :84 (waiting_for)
```

`finalized` tests the AASM `status` column. Incoming documents never reach
`status: "finalized"` — they stay `draft` forever and use `routed_at`
instead as their "done" signal (see the comment at document.rb:109-110,
and the `settled` scope already written to paper over exactly this
distinction). Without a fix, linking an incoming mail to its original would
never remove that original from Waiting.

**Fix:** replace `Document.finalized` with `Document.settled` in both
`todo_for` (document.rb:66) and `waiting_for` (document.rb:84).

No behavior change for existing flows: today nothing ever sets
`in_reply_to_id` on an incoming document (the only current writer is the
`Reply` button's `apply_reply_prefill`, which always creates a *new outgoing*
document), so `Document.finalized` and `Document.settled` currently select
the exact same rows for this query. The fix only takes effect for the new
case this feature introduces.

**Bug B — the "Document chain" card would silently drop/mislink the incoming mail.**

`Document#thread`/`#root`/`#self_and_descendants` (document.rb:226-238) are
direction-agnostic — they'd correctly include a linked incoming mail once
Bug A's fix is in. But two things downstream aren't:

- `DocumentsController#show` (documents_controller.rb:57-62) builds
  `@document_chain` from `base_scope`, which is
  `policy_scope(Document).where(entity: current_entity).outgoing`
  (documents_controller.rb:164) — an incoming document in the thread would
  be silently filtered out of the chain entirely.
- `Documents::ThreadComponent` (thread_component.html.erb) links every
  chain entry with `entity_document_path(document.entity, document)`. For an
  incoming document that's the wrong route — `Documents::RowComponent`
  already handles this distinction (`document.incoming? ?
  entity_incoming_mail_path(...) : entity_document_path(...)`,
  row_component.rb:19) but `ThreadComponent` doesn't.

**Fix:**
- `DocumentsController#show`: build `@document_chain` from `merged_base_scope`
  (documents_controller.rb:169-171, already used by todo/waiting/info,
  covers both directions) instead of `base_scope`.
- `Documents::ThreadComponent`: add a private `document_path_for(document)`
  mirroring `RowComponent#row_path`'s branching, used in place of the
  hardcoded `entity_document_path` call.

Fixing these two turns "Document chain" into exactly the visible trace the
user asked for — no new badge component needed.

## 7. Tests

Model (`document_spec.rb`):
- `repliable_by`: only outgoing/settled/`expects_response: true` documents
  addressed to the given `Party` are returned; excludes other entities,
  other addressees, already-answered originals, `expects_response: false`.
- `waiting_for`: an outgoing document linked from a *routed* (settled)
  incoming mail disappears from the creator's `waiting_for`; stays present
  while unlinked, or while the incoming mail is registered but not yet
  routed.
- `todo_for`: non-regression — assert identical results before/after the
  `finalized`→`settled` swap for the existing (outgoing-only) reply case.
- `thread`/`root`/`self_and_descendants`: a mixed incoming/outgoing thread
  resolves correctly end-to-end.

Controller/request:
- `IncomingMailsController#route`: routing with `in_reply_to_id` present
  persists the link and audit log entry; routing without it (the common
  case) is unchanged.
- `DocumentsController#show`: `@document_chain` includes a linked incoming
  mail; a user without policy access to that incoming mail doesn't see it in
  the chain (`policy_scope` via `merged_base_scope` already enforces this).

View component:
- `ThreadComponent`: link target is `entity_incoming_mail_path` for an
  incoming document, `entity_document_path` for outgoing.

System (Capybara), golden path:
Outgoing document sent to an external party with `expects_response: true` →
appears in creator's Waiting → matching incoming mail registered and routed
with the link set → original disappears from Waiting → "Document chain"
appears on both documents' show pages with correct, working links to each
other.

## 8. Known limitations / explicitly out of scope

- The candidate list in the routing form is scoped to the incoming mail's
  `sender` `Party`. If the external reply arrives from a different address
  than the original was sent to (common in practice — replies often come
  from a different person at the same organization), it won't show up as a
  candidate. No workaround designed; flagged for a future iteration if it
  turns out to matter in practice.
- CC recipients' "Info" tab is untouched — `info_for` doesn't filter
  "already answered" originals today and this feature doesn't change that.
- One incoming mail can link to at most one original (single
  `in_reply_to_id`), matching the existing `Reply`-button semantics. A mail
  that answers multiple outstanding documents at once isn't supported.
