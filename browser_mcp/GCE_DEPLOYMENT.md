# GCE fast browser worker deployment

This runbook prepares the separate browser execution plane defined by the browser ADR. It does not change the existing mcp-shell or Secure MCP Tunnel services.

## Runtime boundary

Run the browser worker as an unprivileged dedicated service account/user. Do not bind a public listener. Reach it only through an authenticated/private MCP transport approved for the environment.

The MVP must start with a fresh isolated Chromium context and no persisted user profile.

## Required runtime

- Node.js 22+
- Chromium and Playwright runtime dependencies
- the repository's `browser_mcp/` package
- optional TypeSafe Jev credentials available only to the server-side worker when Jev selection is enabled

Do not put credentials in Sites metadata or repository files.

## Pre-deployment checks

From the repository:

```sh
npm test --prefix browser_mcp
npm test --prefix sites_mcp
```

Verify that:

- the worker listener is not Internet-accessible
- GCE metadata and RFC1918/link-local destinations remain unreachable through browser policy
- the service user has no unrelated filesystem or deployment credentials
- downloads/uploads and persistent profiles are disabled
- the existing tunnel-client and mcp-shell units are unchanged

## Initial smoke test

Use a public, non-authenticated documentation site. Exercise:

1. navigate
2. accessibility snapshot
3. bounded candidate extraction
4. one safe link/search action
5. independent post-action URL/content verification
6. optional Jev completion judgment

Record wall-clock duration, browser action count, Jev calls, and final verification status.

## Deployment gate

Changing the live GCE runtime, installing Chromium/Playwright packages, adding a systemd service, opening/changing firewall rules, or adding runtime credentials is an operator-approved deployment action. Repository merge does not perform deployment.
