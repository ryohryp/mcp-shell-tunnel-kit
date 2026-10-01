# Sites post-publish smoke test

Run these checks after publishing or re-publishing the **MCP Shell Tunnel Control Plane** Site.

Use only synthetic capability names and the Site's own declarative metadata. Do not include credentials, hostnames, private paths, tunnel IDs, private IPs, or production logs.

## 1. Tool catalog

Confirm the connected Site plugin exposes exactly:

- `describe_control_plane`
- `list_targets`
- `route_request`

No shell, filesystem, Git, service-control, proxy, relay, or generic HTTP tool should be exposed by the Site.

## 2. Describe the boundary

Call:

```json
{}
```

with `describe_control_plane`.

Pass criteria:

- `status = "ok"`
- `policy.role = "sites_control_plane"`
- the invariants state that Sites does not execute shell commands
- the invariants state that execution remains on the host-local `mcp-shell` executor
- execution capabilities are listed under `host_local_executor`

## 3. Empty target registry

With no `MCP_SHELL_TARGETS_JSON` configured, call `list_targets` with:

```json
{}
```

Expected contract:

```json
{
  "status": "ok",
  "targets": [],
  "metadata_only": true,
  "live_status": false
}
```

The Sites runtime may wrap the handler result in runtime-specific content/structured-content fields. The inner handler contract is what matters.

## 4. Host-local routing

Call `route_request`:

```json
{
  "capability": "command_run"
}
```

Expected fields:

```json
{
  "status": "ok",
  "capability": "command_run",
  "route": "host_local_executor",
  "requires_host_local_executor": true
}
```

Repeat with `filesystem_read` and `git_write`; both must remain host-local.

## 5. Sites-only routing

Call `route_request`:

```json
{
  "capability": "policy_info"
}
```

Expected fields:

```json
{
  "status": "ok",
  "capability": "policy_info",
  "route": "sites_control_plane",
  "requires_host_local_executor": false
}
```

Repeat with `target_discovery`.

## 6. Unknown capability fails closed

Call `route_request`:

```json
{
  "capability": "arbitrary_shell"
}
```

Expected application-level result:

```json
{
  "status": "failed",
  "error": "invalid_input"
}
```

It must not attempt execution or proxying.

## 7. Optional synthetic target metadata check

Only if the Site runtime supports a reviewed non-secret environment value, configure this synthetic registry:

```json
[
  {
    "id": "example-linux",
    "label": "Example Linux target",
    "platform": "linux",
    "executor": "host_local_executor",
    "capabilities": ["filesystem_read", "git_read"],
    "tags": ["synthetic"]
  }
]
```

Then:

- `list_targets` should return only that metadata
- `route_request({"capability":"filesystem_read","target_id":"example-linux"})` should route to `host_local_executor`
- `route_request({"capability":"command_run","target_id":"example-linux"})` should fail with `capability_not_declared`

Remove the synthetic registry after testing if it is not intended to remain.

## 8. Independent host-local verification

The Site smoke test verifies only the control plane.

Separately use the existing Secure MCP Tunnel connector to verify host-local functionality such as `system_info` or the smallest relevant typed/read-only tool. Do not infer host connectivity from a successful Site tool call.
