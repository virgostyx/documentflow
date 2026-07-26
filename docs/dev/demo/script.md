# DocumentFlow — Live Demo Script

Registration → Validation → Signing → Sending, for a document that needs no reply,
on documentflowmanagement.com. See the seed script at `db/demo_seed.rb` and the
sample file at `docs/dev/demo/office_relocation_notice.pdf`.

Verified against a local dry run on 2026-07-26 (see notes below) — this script
reflects actual app behavior, not assumptions from reading the code.

## Cast

| Persona | Title | Workflow role(s) | Email |
|---|---|---|---|
| Sarah Kone | Executive Assistant | RED, EXP | virgostyx+sarah@gmail.com |
| David Mensah | Department Director | VISA | virgostyx+david@gmail.com |
| Amara Diallo | General Manager | SIGN | virgostyx+amara@gmail.com |
| Youssef Traoré (addressee, no login) | Traoré & Partners | — | virgostyx+youssef@gmail.com |

Password for all three logins: `MeridianDemo2026!`
Sign-in: `documentflowmanagement.com/users/sign_in`

All four emails use Gmail plus-addressing to your own inbox, so every
notification the app fires during the demo — including the one addressed to
the "external" client — actually lands somewhere you can show.

## Before you go live

- Run `bin/rails runner db/demo_seed.rb` against production once, in advance.
- Have `docs/dev/demo/office_relocation_notice.pdf` ready to upload.
- Create three separate **Chrome/Edge profiles** (avatar icon → Add), one per
  persona — **not** private/incognito windows. All incognito windows in a
  browser share one session, so a second incognito window shows the same
  logged-in account as the first, not a fresh one. Sign in to each profile
  ahead of time as Sarah, David, and Amara — no sign-out waiting mid-pitch.
- Have your Gmail inbox open in a fourth tab.
- If a previous demo document exists, delete it from Sarah's account first
  (Actions → Delete, only available before finalization) or just create a
  new one — the seed data is reusable either way.

## Act 1 — Registration (Sarah, RED)

1. Sign in as Sarah, open Meridian Advisory Group, click **New document**.
2. Subject: "Notice of Office Relocation – New Address Effective September 2026".
   Leave Document date as today.
3. Sender → Sarah Kone. Addressee → Youssef Traoré. Leave **"This document
   expects a response from the recipient"** unchecked.
4. Click **Create document** → *"Document created successfully."*
5. Upload `office_relocation_notice.pdf` as the main file →
   *"Main document uploaded successfully."*
6. In the validation circuit card, apply the **Standard Notice** template →
   *"Circuit template applied successfully."*
7. Open **Actions** → **Launch** → a confirmation dialog appears
   ("Launch this document into its validation circuit?") → click **Confirm**
   → *"Document launched successfully."* Status becomes **In Progress**.
8. **Launching does NOT auto-approve the RED step** — open **Actions** →
   **Approve** once more, as Sarah, for her own RED step →
   *"Step approved successfully."* Only now is the document actually waiting
   on David.

## Act 2 — Validation (David, VISA)

9. Switch to David's window — the document already shows under **To Validate**
   on his dashboard.
10. Open it → **Actions** → **Approve** → *"Step approved successfully."*
    (**Reject** is also available here — RED is the only role that can never reject.)

## Act 3 — Signing (Amara, SIGN)

11. Switch to Amara's window, open the document → **Actions** → **Approve**
    → *"Step approved successfully."* Status flips to **Signed** and the
    document is frozen from here on.

## Act 4 — Sending (Sarah, EXP)

12. Switch back to Sarah's window, open the document → **Actions** →
    **Approve**. Status flips to **Finalized**.
13. A share link is generated **automatically** the moment the document is
    finalized — no extra click needed. It's already listed under
    **Public sharing** on the document page, and it's the same link embedded
    in the notification email sent to Youssef.
14. Switch to the Gmail tab: two new emails should have landed —
    "Document finalized: ADMIN(2026)0000X" and "Document addressed to you:
    ADMIN(2026)0000X" (the one Youssef would receive).
15. Open the share link — this is exactly what Youssef Traoré sees: the
    finalized PDF, a Finalized badge, no login, nothing to reply to.

## The line to land

Four different people, four different sessions, never once emailed, called,
or Slacked each other — and the document still moved from a blank form to a
signed, delivered PDF in a few minutes, with a full audit trail behind it.
And this was the simple case: nobody even had to reply.

## Notes from the dry run (2026-07-26, local)

- **RED does not auto-approve on Launch** in the current codebase — Sarah
  must click Approve on her own step after launching. (An earlier design
  note in project memory said otherwise; that turned out to be stale —
  verify behavior against the running app, not notes, before a live demo.)
- **Launch requires confirming a modal** ("Launch this document into its
  validation circuit?" → Confirm) — the app uses a custom confirmation
  dialog, not a browser `confirm()`.
- **A share link auto-generates at finalization** (`Document#active_shared_link`
  lazily creates one) and is embedded in the addressee notification email —
  the manual "Generate share link" button is only needed for extra/rotated
  links.
- Members (not owners/admins) need an explicit department assignment or the
  **New document** button never renders (`DocumentPolicy#create?`) — the
  seed script assigns all three demo users to General Administration for
  this reason.
- A "Buy Me a Coffee" floating widget on the marketing/login pages intercepts
  clicks on the cookie-consent banner underneath it. Cosmetic, unrelated to
  this demo, but worth a heads-up separately — it could catch an errant
  click during a live pitch.
