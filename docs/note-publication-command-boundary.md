# note publishing: use the existing authenticated Orbit command path

The Personal Orbit Server / MCP Shell Tunnel connector is a **diagnostic,
read-only inspection** surface. Its `run_script` entries are administrator-
defined, fixed-argument host diagnostics; `writes_enabled: false` for typed
tools **does not** prevent an allowlisted script from performing external writes.

Do **not** add a `note_publish` (or generic `curl`/`node`/`sh`) mapping to
`security.scripts`. Such a mapping would give an AI-facing diagnostic tool a
separate posting capability without the publication workflow's bounded,
per-operation authorization. It would also couple this reusable kit to one
application's cloud credentials.

## Existing PC-independent path

The application's authority for note publication is
`ryohryp/personal-orbit`, not this kit. Its current main contains:

1. A dedicated GitHub [Command Inbox issue #1105](https://github.com/ryohryp/personal-orbit/issues/1105), accepting an explicitly marked command comment **from the pinned owner only**.
2. `.github/workflows/chat-note-command.yml`, which verifies the pinned
   issue/actor before running the trusted default-branch dispatcher, obtains
   a short-lived GitHub Actions OIDC token, and sends the command to the
   Always-on Secretary Runtime. It deliberately carries no production secret
   and runs on the isolated CI runner, not a Local Worker.
3. `scripts/submit-github-note-command.mjs` and
   `src/routes/githubNoteCommandIngress.ts`, supporting
   `submit_article`, `prepare_publish`, `status`, and `approve_request`.
   Results are returned through a separate, marked issue comment.
4. The application's existing Note Publication V3 / Cloud External Executor
   workflow, which owns approval, target/payload binding, idempotency, receipt,
   uncertain outcomes, and reconciliation. The GitHub command transport does
   **not** replace those checks.

Use the application's documented command shape, validators and existing
approved article package. Never send session state, cookies, credentials,
tokens or unrelated private material in a GitHub comment. A result comment
that says `queued` is *not* evidence of a saved draft or published post.

## Current rollout gate

As of 2026-09-24, the application tracks production PC-OFF acceptance in
[personal-orbit #1011](https://github.com/ryohryp/personal-orbit/issues/1011).
The latest note canary investigation reached an in-place login form on an
existing editor URL, rather than an authenticated editor. This is evidence
that the cloud session is **not ready**; it does not, by itself, establish
the cookie's expiration cause. Do not activate the executor or submit a
new draft solely because this kit's MCP connection and `uptime` work.

Resume through #1011's explicit gates: approved cloud-session bootstrap,
read-only canary with the existing editor draft, separately approved
production activation, then approved draft-write and final-publication
E2E checks. Record the resulting receipt and public URL via the application's
readback. In an unknown-outcome case, reconcile the *same* operation; never
automatically resubmit it or fall back to Local Worker.

**Boundaries:** This kit does not install, configure, approve or invoke note
publishing, and merging documentation does not update the active server.
Production deployment, credential/session changes, service restarts, draft
writes and final publication require their own explicit approval.
