# Sites MCP control-plane PoC

This directory is an experimental ChatGPT Sites MCP layer for `mcp-shell-tunnel-kit`.

It deliberately does **not** replace `tunnel-client` or `mcp-shell`. The Site is a small, host-independent control plane; file access, Git operations, process execution, live host status, and service control remain on the host-local executor.

## Boundary

```text
ChatGPT
  |
  +-- Sites MCP control plane
  |     |- describe_control_plane
  |     |- list_targets (declared metadata only)
  |     '- route_request
  |
  '-- OpenAI Secure MCP Tunnel
        |
        tunnel-client on target environment
        |
        mcp-shell secure mode
        |- scoped filesystem / Git tools
        '- allowlisted fixed-argv run_script
```

Sites does not proxy or relay commands to the target host in this PoC.

## Target registry

Optional target metadata can be supplied through `MCP_SHELL_TARGETS_JSON`. This variable is **not a connection configuration**. It can contain only:

- `id`
- `label`
- `platform`
- `executor` (must be `host_local_executor`)
- `capabilities`
- `tags`

Unknown fields are rejected. That intentionally excludes hostnames, URLs, IP addresses, credentials, tokens, tunnel IDs, and private keys.

Example synthetic metadata:

```json
[
  {
    "id": "example-linux",
    "label": "Example Linux target",
    "platform": "linux",
    "executor": "host_local_executor",
    "capabilities": ["filesystem_read", "git_read"],
    "tags": ["example"]
  }
]
```

The registry is declarative and does not imply that a target is currently online.

## Tool wiring

`server.js` exports handler functions plus a `tools` metadata array. Wire those handlers to the MCP tool registration API available in ChatGPT Sites.

All three PoC tools are read-only and perform no target-side actions.

## Tests

```sh
npm test
```

The tests are offline and verify that execution capabilities remain host-local and that connection details cannot be represented in the Sites target registry.

## Publish and verify

For Site creation or updates, follow [SITE_UPDATE.md](SITE_UPDATE.md). The repository remains the source of truth; re-publishing a previously saved Site is not a substitute for synchronizing the current implementation.

After publishing, run the synthetic [SMOKE_TEST.md](SMOKE_TEST.md) contract before treating the Site control plane as ready.
