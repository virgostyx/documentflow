# In-browser document editing (WOPI / Collabora Online) — local dev & manual verification

This feature lets a user check out a document and edit its main file directly
in the browser (an iframe embedding Collabora Online) instead of the manual
download/edit/re-upload flow. It's implemented via the WOPI protocol:
`app/controllers/wopi/files_controller.rb` is the "WOPI host" side; a
self-hosted Collabora Online container is the "WOPI client" side.

The manual check-in flow (`Check in manually` / `Cancel checkout`) still
works exactly as before and is not affected by any of this — it's the
required fallback for when Collabora is unavailable.

## Running Collabora locally

```
docker compose -f docker-compose.collabora.yml up
```

Then start the Rails server with `COLLABORA_BASE_URL` pointing at it:

```
COLLABORA_BASE_URL=http://localhost:9980 bin/rails server
```

Without `COLLABORA_BASE_URL` set, `Wopi::EditUrl.for` returns `nil` and the
"Edit online" modal falls back to its "Online editor unavailable" state —
the app does not crash or require Collabora to be running.

## Manual verification checklist

Automated coverage stops at the boundary Rails owns: `spec/requests/wopi/files_spec.rb`
covers the WOPI protocol surface (CheckFileInfo/GetFile/PutFile/Lock/Unlock/
RefreshLock), and `spec/components/documents/main_file_component_spec.rb`
covers button visibility. What those specs **cannot** exercise is Collabora's
actual LibreOffice-in-iframe rendering or its postMessage handshake — there's
no headless Collabora in CI, and a system spec that only asserts an `<iframe>`
tag exists would give false confidence. Verify this manually before shipping
any change that touches this code path:

1. Check out a document (or use the seed data) that has a `.docx` main file
   attached, while it's in an in-progress (not yet signed) workflow step.
2. As the current step's actor, click **Edit online**.
3. Confirm the Collabora editor loads inside the modal iframe and the
   document is editable.
4. Make an edit; confirm it autosaves (`PutFile` calls in the Rails log)
   without releasing the checkout (`document.checked_out_by` stays set).
5. Click **Done editing**; confirm the checkout is released
   (`document.checked_out_by` becomes `nil`) and a new `DocumentFileVersion`
   was created with the edited content.
6. Stop the Collabora container and repeat step 2 — confirm the modal shows
   "Online editor unavailable" instead of a 500, and that "Check in manually"
   / "Cancel checkout" still work normally.
