# ChatGPT Sites publish/update procedure

Use this procedure to create or update the **MCP Shell Tunnel Control Plane** Site from this repository.

## Source of truth

The repository is authoritative. Before publishing or re-publishing the Site, synchronize these files from the current `main` branch:

- `sites_mcp/policy.js`
- `sites_mcp/target-registry.js`
- `sites_mcp/server.js`

Do not regenerate the security boundary from prose. Use the current source verbatim unless the repository itself is intentionally changed and reviewed first.

The existing Secure MCP Tunnel and host-local `mcp-shell` deployment remain separate from the Site and must not be replaced by this update.

## Site role

The Site is a **non-executing control plane**. It may:

- describe the control-plane policy
- list declarative, non-secret target metadata
- classify where a capability must run

It must not:

- execute shell commands
- read or write a target filesystem
- run target Git operations
- query live host status
- control target services
- proxy or relay commands to a host
- store hostnames, URLs, IP addresses, credentials, tokens, tunnel IDs, private keys, or other connection details

## Required MCP tool boundary

The Site must expose exactly these three tools.

### `describe_control_plane`

Input schema:

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {}
}
```

Metadata:

- `readOnlyHint: true`
- `openWorldHint: false`

### `list_targets`

Input schema:

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {}
}
```

Metadata:

- `readOnlyHint: true`
- `openWorldHint: false`

The result is declarative metadata only. It is not a live connectivity or health check.

### `route_request`

Input schema:

```json
{
  "type": "object",
  "required": ["capability"],
  "additionalProperties": false,
  "properties": {
    "capability": { "type": "string" },
    "target_id": { "type": "string" }
  }
}
```

Metadata:

- `readOnlyHint: true`
- `openWorldHint: false`

## Required routing contract

These capabilities must route to `sites_control_plane`:

- `policy_info`
- `target_discovery`

These capabilities must route to `host_local_executor`:

- `filesystem_read`
- `filesystem_write`
- `git_read`
- `git_write`
- `command_run`
- `live_status`
- `service_control`

Do not add a Site-side execution fallback.

## Target registry

`MCP_SHELL_TARGETS_JSON` is optional and must remain a declarative metadata registry only.

Allowed fields are exactly:

- `id`
- `label`
- `platform`
- `executor`
- `capabilities`
- `tags`

`executor` must equal `host_local_executor`.

If the initial Site is published without target metadata, leave `MCP_SHELL_TARGETS_JSON` unset. `list_targets` should then return an empty list. That is a valid initial deployment.

Do not put connection information or credentials into this variable.

## Minimal Site page

Keep the website surface intentionally small. It should explain:

- this Site is the MCP Shell Tunnel control plane
- it does not execute host commands
- host-local execution remains behind OpenAI Secure MCP Tunnel + `mcp-shell`
- target discovery is declarative, not live status

No interactive executor UI is required for this PoC.

## Create/update instruction for ChatGPT Sites

When creating or editing the Site, use the current contents of `policy.js`, `target-registry.js`, and `server.js` as the MCP implementation.

Register exactly the three tools documented above and preserve their schemas and read-only hints. Do not add additional tools, command relays, arbitrary HTTP forwarding, generic shell inputs, or connection configuration.

For a first publication, leave the target registry empty unless non-secret declarative metadata has been explicitly reviewed.

Only publish after the Site source matches repository `main`.

## Post-publish verification

After publication, follow [SMOKE_TEST.md](SMOKE_TEST.md).

A successful Site publication does not by itself prove that the host-local Secure MCP Tunnel is connected or healthy. Verify the Site control plane and host-local executor independently.
