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

## Roll back

If the service fails to start or the MCP catalog is unexpectedly reduced, restore the **host-local** backups of the active security file, profile and/or unit that were changed. Then run `sudo systemctl daemon-reload` if the unit changed, restart the affected Tunnel service and repeat the health and tool checks. Do not restart unrelated application services.

## Security reminders

- `writes_enabled: false` disables mcp-shell's typed write tools; it does **not** make every operator-defined script read-only. Review script binaries and arguments.
- `systemctl status`, `journalctl`, Git output and some process listings may reveal host-specific or sensitive metadata. Sanitize before sharing.
- Allowlist scripts are not a general-purpose shell; avoid `bash -c`, `sh -c`, shells, package managers or user-controlled parameters.
- Avoid adding more than a few diagnostic commands until there is a clear operational need.
