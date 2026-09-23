# Operations: installation, verification and rollback

This is an **example workflow**, not an automatic deployment script. Review commands and file ownership for your host. Production changes, secret provisioning and service restarts should be approved by the operator.

## Before changes

1. Check versions and documentation for [mcp-shell v1.0.0](https://github.com/sonirico/mcp-shell/tree/v1.0.0) and [tunnel-client v0.0.14](https://github.com/openai/tunnel-client/tree/v0.0.14).
2. Inspect the active service and its configured stdio target with `systemctl cat tunnel-client.service`; **do not** paste environment file contents or real profiles into issue reports.
3. Confirm the target mcp-shell process has `MCP_SHELL_SEC_CONFIG_FILE` pointing to the intended security file. Back up that file and the service/profile files **outside Git**.
4. Ensure the service user is unprivileged and has access only to the necessary workspace. Real credentials should live in a root-controlled environment file (typically `0600`). Do not use `MCP_SHELL_ALLOW_UNSAFE=1`.

## Install / update an existing VM

Adapt and validate the templates before use; never overwrite a working configuration blindly.

- Copy `examples/security.yaml` to the intended location; set an existing, dedicated workspace, and review every script definition.
- Place the executable wrapper on the host and change `MCP_SHELL_BIN`/`MCP_SHELL_SEC_CONFIG_FILE` as needed.
- Use tunnel-client's own profile tooling to create a valid profile, with the **main** stdio channel invoking that wrapper by absolute path.
- Place the adapted unit in `/etc/systemd/system/`. For an existing installation, preserve its current unit and service name; only change what is necessary.
- Run `tunnel-client doctor --profile server-stdio --profile-dir /opt/tunnel-client/profiles` with the actual paths/profile and resolve any diagnostics.
- After approval, run `sudo systemctl daemon-reload`, `sudo systemctl restart tunnel-client.service`, and `systemctl is-active tunnel-client.service`.

## Verify end-to-end

Check the actual deployed unit, process and recent logs without exposing secrets:

```sh
systemctl is-active tunnel-client.service
pgrep -a mcp-shell
sudo journalctl -u tunnel-client.service -n 30 --no-pager
```

Logs should show the intended security file, `security_enabled=true`, `writes_enabled=false`, `scripts=3` and a successfully started Tunnel. Service health alone does **not** prove the tools are visible in ChatGPT. Refresh the connector catalog if needed, then invoke `run_script` for `uptime`, `memory` and `disk` through ChatGPT and verify their output. Confirm the existing typed read tools still work.

## Opt-in development workspace

When ChatGPT must edit repository files, use a separate, dedicated development workspace and start from `examples/security-development.yaml` rather than changing the read-only template in place.

- `writes_enabled: true` enables mcp-shell's typed write tools only within the configured working directory. Treat that directory boundary as the primary write boundary and keep credentials, deployment profiles, unrelated repositories and backups outside it.
- Keep `MCP_SHELL_ALLOW_UNSAFE` unset. Typed writes do not require arbitrary shell access.
- Add execution one operation at a time as fixed argv. Prefer non-mutating validation commands and repository-owned scripts with stable arguments. Do not expose `sh -c`, `bash -c`, interpreters, package managers, `sudo`, or caller-controlled paths/arguments.
- Do not allow deployment, service restart, credential/session changes, publication, or other external side effects merely because repository writes are enabled. Those remain separately authorized operations.
- Before enabling this profile on a VM, review the effective workspace permissions and active security file through an independently authorized Linux-native administration path.

A useful first validation is: create a disposable file through the typed write tool, read it back, update it, delete it, then run only the allowlisted `git_status` and `git_diff_check` checks. Verify attempts to access paths outside the workspace remain denied.

### One-time GCE bootstrap for the development profile

The live MCP connection must not modify its own security policy or restart its own Tunnel service. On Google Compute Engine, perform the initial switch through an independently authorized GCP-native administration path (Cloud Console SSH, Cloud Shell plus authorized Compute Engine SSH, or an existing Linux SSH path). This is a bootstrap operation, not a steady-state MCP capability.

Before changing anything, identify the **actual** service name, service user, wrapper, security file and workspace from the deployed unit. Do not assume the example paths below match the VM, and do not paste profiles, environment files, host identifiers or credentials into GitHub or ChatGPT.

1. Fetch the reviewed repository revision containing the development profile through the host's normal source-management procedure.
2. Create or select a dedicated repository/worktree owned by the unprivileged MCP service user. It must contain no credentials, Tunnel profiles, environment files, backups or unrelated repositories.
3. Copy `examples/security-development.yaml` to a host-local security file and replace only the workspace path and explicitly reviewed fixed-argv scripts. Keep `security.enabled: true`, `writes_enabled: true`, and keep `MCP_SHELL_ALLOW_UNSAFE` unset.
4. Validate ownership and permissions, then point the existing secure wrapper at that host-local security file. Preserve the previous security file and wrapper configuration outside the MCP workspace for rollback.
5. Run the installed `tunnel-client doctor` against the actual profile. If it fails, stop and roll back rather than widening privileges.
6. Restart **only** the Tunnel service after operator approval. Confirm it is active and that the service still runs as the intended unprivileged account.
7. Refresh the ChatGPT connector/tool catalog. The expected change is the appearance of typed write tools; arbitrary shell, `sudo`, package-manager and service-management tools must remain absent.
8. Perform the disposable-file create/read/update/delete test inside the workspace, then run only the allowlisted validation commands. Confirm a path outside the workspace is rejected.

After bootstrap, routine repository editing and validation should flow through typed MCP tools and narrow fixed-argv scripts. Configuration changes, service restarts, credential operations and deployment remain outside the steady-state MCP authority unless separately designed and approved.

## Roll back

If the service fails to start or the MCP catalog is unexpectedly reduced, restore the **host-local** backups of the active security file, profile and/or unit that were changed. Then run `sudo systemctl daemon-reload` if the unit changed, restart the affected Tunnel service and repeat the health and tool checks. Do not restart unrelated application services.

## Security reminders

- `writes_enabled: false` disables mcp-shell's typed write tools; it does **not** make every operator-defined script read-only. Review script binaries and arguments.
- `systemctl status`, `journalctl`, Git output and some process listings may reveal host-specific or sensitive metadata. Sanitize before sharing.
- Allowlist scripts are not a general-purpose shell; avoid `bash -c`, `sh -c`, shells, package managers or user-controlled parameters.
- Avoid adding more than a few diagnostic commands until there is a clear operational need.
