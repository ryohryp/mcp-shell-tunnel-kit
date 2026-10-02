# ADR: Separate GCE browser execution plane from Sites control plane

## Status

Proposed

## Context

The existing Sites MCP layer is intentionally host-independent and non-executing. It exposes only policy, declarative discovery, and routing. Browser automation is execution: navigation can reach untrusted origins, actions can mutate remote state, and browser sessions can hold credentials.

Putting Playwright directly into the Sites layer would violate the existing control-plane boundary and make SSRF, credential, and side-effect policy harder to enforce.

## Decision

Add a separate `browser_mcp/` execution plane intended to run on GCE. Sites may classify and route a `browser_read` capability to this executor, but it does not proxy browser commands itself.

The MVP is deliberately read-oriented:

- public HTTP(S) origins only
- fresh isolated context per session
- no authenticated profile or credential entry
- no file uploads/downloads
- no arbitrary JavaScript
- semantic/accessibility refs are the primary action surface
- allowlisted actions only: navigate, follow link, click safe controls, fill non-sensitive search/text fields, back
- strict action/time/snapshot budgets
- private, loopback, link-local, metadata-service and non-HTTP(S) destinations fail closed

Jev is an advisory System One layer. It can choose among already-extracted bounded action candidates and judge semantic completion. It cannot expand the action allowlist, bypass network policy, or authorize side effects. Exact URL/network validation and execution budgets remain deterministic.

## Execution model

```
Sites control plane
  -> route browser_read to browser_executor
  -> authenticated/private transport
  -> GCE browser_mcp
       -> deterministic URL guard
       -> Playwright Chromium
       -> accessibility snapshot + bounded candidates
       -> optional Jev choice
       -> deterministic action validator
       -> Playwright action
       -> deterministic + semantic verification
```

For `execute_goal`, the fast loop remains inside GCE so individual clicks do not require a ChatGPT/Sites round trip.

## Consequences

- Existing Secure MCP Tunnel and mcp-shell remain unchanged.
- Existing Sites tools remain non-executing.
- Browser execution can evolve independently and can later support stronger profiles only through a separate reviewed policy.
- Live GCE deployment is a production/runtime change and requires explicit operator approval.
