# WebAuthn Passwordless Login (Passkeys) — Implementation Plan

Status: IMPLEMENTED (2026-07-31). 1538/1538 specs green (excluding one
pre-existing, unrelated flaky JS system spec in the checkout feature —
confirmed flaky on `main` before this branch too), RuboCop clean, no new
Brakeman warnings, no vulnerable transitive deps introduced.

## 1. Concept

Add WebAuthn/FIDO2 passkeys as a **full replacement** for password
authentication — the web equivalent of SSH public/private-key login.
Registering a passkey is what makes an account "passwordless"; from that
point on the account signs in with the passkey alone (biometric/PIN-gated,
phishing-resistant), never a password, and a verified passkey satisfies
mandatory 2FA by itself — no separate TOTP step. If the passkey is lost, a
one-time-use recovery code (reusing the existing TOTP backup-code
infrastructure) lets the user back in once to register a new one.

This sits alongside the existing TOTP-based mandatory 2FA (`4a549b7`) rather
than replacing it outright — a user who never registers a passkey keeps
using password + TOTP exactly as before.

## 2. Decisions validated with the user

| Question | Decision |
|---|---|
| Coexist with password, or full replacement? | **Full replacement.** `User#passwordless?` is derived (`webauthn_credentials.exists?`), not a stored flag — registering a first passkey *is* going passwordless; removing the last one restores password sign-in. |
| Does a passkey login still need a TOTP step for owner/admin/super_admin? | **No.** A `user_verification: "required"` assertion is treated as MFA-equivalent by itself. A passwordless user may also freely disable any existing TOTP. |
| Recovery if the only passkey is lost? | **One-time-use recovery codes**, generated on first passkey registration via the existing `:two_factor_backupable` mechanism (`generate_otp_backup_codes!` / `invalidate_otp_backup_code!`) — no new hashing/storage system. |
| Login page UX? | **Conditional UI** (WebAuthn autofill) on the email field, plus an explicit "Sign in with a passkey" button for browsers without conditional-UI support. |
| Password re-entry to remove a passkey? | Not separately gated in the controller beyond normal session auth — removing a credential is an authenticated, in-session action; no `current_password` prompt (consistent with the profile-edit decision below). |
| Passkey limit per user? | None. |
| Passkey nickname mandatory? | **Yes** — required at registration, no silent default. |
| Distinguish platform vs. roaming authenticators in the UI? | Deferred — no `authenticator_attachment` column. |
| Profile edits (name/email) for passwordless users? | **No `current_password` required** — the already-open, UV-gated passkey session is treated as sufficient, via a `Users::RegistrationsController#update` override using `update_without_password`. |
| Recovery-code sign-in: auto-regenerate codes after use? | **No** — redirect to passkey management with a prompt to register a new passkey and manually regenerate (existing "Regenerate" button). |

## 3. Schema

```ruby
# AddWebauthnIdToUsers
add_column :users, :webauthn_id, :string
add_index :users, :webauthn_id, unique: true

# CreateWebauthnCredentials
create_table :webauthn_credentials do |t|
  t.references :user, null: false, foreign_key: true
  t.string :external_id, null: false   # WebAuthn credential ID
  t.string :public_key, null: false
  t.string :nickname, null: false
  t.bigint :sign_count, null: false, default: 0
  t.datetime :last_used_at
  t.timestamps
end
add_index :webauthn_credentials, :external_id, unique: true
add_index :webauthn_credentials, [:user_id, :nickname], unique: true
```

`webauthn_id` (the WebAuthn "user handle") is lazily generated and persisted
on first read (`User#webauthn_id`, `WebAuthn.generate_user_id`) rather than
backfilled in bulk — it's only needed once a user actually registers a
passkey.

## 4. Models

- `WebauthnCredential` — `belongs_to :user`; presence on `external_id`,
  `public_key`, `nickname`; uniqueness on `external_id` (global) and
  `nickname` (scoped to `user_id`).
- `User` — `has_many :webauthn_credentials, dependent: :destroy`;
  `passwordless?` (`webauthn_credentials.exists?`); lazy `webauthn_id`.

## 5. Registration ceremony (`Users::PasskeysController`, authenticated)

`options_for_create` is called with
`authenticator_selection: { resident_key: "required", user_verification: "required" }`
— **discoverable** (so login can be usernameless) and **UV-required** (so a
passkey alone can stand in for MFA). On `create`, the nickname is required
(422 if blank) before the ceremony is even verified. On a user's **first**
credential, `generate_otp_backup_codes!` is also called and the plaintext
codes are returned once in the JSON response (never persisted anywhere in
plaintext) for the client to display inline.

`destroy` removes a credential and, if none remain, redirects a
mandatory-2FA user with no TOTP configured to `two_factor_setup_path`;
otherwise it just confirms removal (password sign-in becomes available
again automatically, since `passwordless?` is derived).

**Gotcha hit during implementation:** `current_user.webauthn_credentials`
can carry a stale association cache into the `.none?` check right after
`destroy!`, if the association was already touched earlier in the same
request (e.g. via `enforce_two_factor_setup`'s `passwordless?` check running
as a before_action before the controller action). Fixed by calling
`current_user.webauthn_credentials.reload` before the post-destroy check.

## 6. Passwordless sign-in (`Users::PasskeySessionsController`, unauthenticated)

Discoverable-credential ceremony — `options_for_get` is called with **no**
`allow` list, so the server doesn't need to know who's signing in ahead of
time. On `create`, the assertion's credential ID resolves the
`WebauthnCredential` → owning `User`; the assertion's `userHandle` is
cross-checked against `user.webauthn_id` via `ActiveSupport::SecurityUtils.secure_compare`
as defense in depth. `WebAuthn::SignCountVerificationError` (possible cloned
authenticator) is caught and rejected with a distinct message; a successful
verify calls `sign_in(user)` directly — **never** touches
`session[:otp_user_id]` or the TOTP challenge controller.

## 7. Blocking password auth for passwordless accounts

Three surfaces had to be closed:

- `Users::SessionsController#create` — checks `user&.passwordless?` first,
  before ever calling `valid_password?`, and redirects with guidance.
- `Users::PasswordsController#create` (new) — blocks the "forgot password"
  email for passwordless accounts, pointing to recovery codes instead.
- **The Warden strategy itself** (`config/initializers/devise_two_factor_authenticatable_patch.rb`).
  This was the subtle one: Warden performs *opportunistic* authentication —
  any call to `user_signed_in?`/`current_user` for a not-yet-authenticated
  scope makes Warden silently try to authenticate using whatever's in the
  *current* request's params, including on the sign-in POST itself, via
  `ApplicationController#enforce_two_factor_setup`'s otherwise-harmless
  `user_signed_in?` check running as a before_action **before** the
  controller action body. devise-two-factor's strategy treats "no OTP
  required" as "password alone is enough" — and passwordless accounts never
  set `otp_required_for_login`, so without this patch their old password
  would silently sign them in via that side channel, completely bypassing
  the controller-level check above. Fixed by prepending a module onto
  `Devise::Strategies::TwoFactorAuthenticatable` that fails `validate_otp`
  outright when `resource.passwordless?`. This is the actual root-cause fix;
  the controller-level checks above are useful for the friendly redirect
  message but do not, by themselves, prevent the silent sign-in.

`enforce_two_factor_setup` also gained `|| current_user.passwordless?` in
its early-return, and `Users::TwoFactorSetupsController#destroy`'s mandatory-2FA
guard became `two_factor_required? && !passwordless?` (a passwordless user
may freely disable TOTP, since the passkey already covers MFA).

## 8. Recovery-code sign-in (`Users::RecoveryCodeSessionsController`, unauthenticated)

Reuses `User#invalidate_otp_backup_code!` as-is, but **gated on
`user.passwordless?`** — without that gate, a legacy TOTP-only user's
existing backup codes (meant only for the post-password OTP challenge) would
also work on this new unauthenticated endpoint, bypassing password+TOTP
entirely for an account that never opted into passwordless. On success,
redirects to `passkeys_path` with a prompt to register a new passkey.

## 9. Views / JS

- `devise/sessions/new.html.erb` — conditional-UI Stimulus controller on the
  email field (`autocomplete="username webauthn"`), explicit "Sign in with a
  passkey" button, "Lost your passkey?" link; password form unchanged below.
- `users/passkeys/index.html.erb` — management page: credential list with
  per-item removal, mandatory-nickname registration form, one-time backup
  codes shown inline via JS after first registration, recovery-code
  regeneration for passwordless users.
- `users/recovery_code_sessions/new.html.erb` — email + code form.
- `devise/registrations/edit.html.erb` — new "Passkeys" section; password
  change and current-password confirmation blocks hidden entirely for
  passwordless users.
- `@github/webauthn-json` pinned via importmap; `passkey_registration_controller.js`
  and `passkey_login_controller.js` follow the existing fetch +
  `X-CSRF-Token` meta-tag pattern used elsewhere in the app.

## 10. Tests

Real WebAuthn ceremonies in request specs via the gem's own
`WebAuthn::FakeClient` (`spec/support/webauthn_helpers.rb`) rather than ad
hoc stubbing — this exercises the actual cryptographic verify path, not a
mock of it. Coverage: registration (mandatory nickname, first-time backup
codes, destroy guards), passwordless sign-in (discoverable credential, TOTP
bypass, sign_count replay rejection, userHandle mismatch rejection),
password/reset blocking for passwordless accounts, recovery-code sign-in
(including the cross-account gate), and `enforce_two_factor_setup`/TOTP
`destroy` guard relaxation for passwordless users.

## 11. Known limitation

End-to-end browser verification (real Touch ID / USB key / conditional-UI
autofill) was not performed — this environment has no real authenticator
hardware or interactive browser session. The FakeClient-driven request
specs are the strongest automated verification available short of that;
manual verification in a real browser is recommended before relying on this
in production.
