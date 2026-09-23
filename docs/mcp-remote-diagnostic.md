# Optional MCP read-only Linux systemd posture diagnostic

`linux_posture` is an **opt-in** extension for an already working, operator-managed
Linux deployment. It returns bounded PASS/FAIL/UNVERIFIED labels and does **not**
expose arbitrary shell, user-supplied paths/arguments, configuration contents,
logs or credentials. This does not replace an independently authorized host-side
access path for troubleshooting a broken Tunnel.

## Install only after operator approval

1. Review `scripts/verify-linux-posture-remote.sh` and run the offline
   `tests/test-verify-linux-posture-remote.sh` tests before deployment.
2. Install the script in a root-owned, immutable-to-service-user location at
   `/opt/mcp-shell-tunnel-kit/scripts/verify-linux-posture-remote.sh` (the example
   path). Set owner `root:root`, mode `0755`, and protect every parent directory
   from writes by the Tunnel/MCP service user. Use an absolute path; do not put
   the script in the dedicated MCP file-tool workspace.
3. Before installing, edit the two hard-coded constants `SERVICE_NAME` and
   `ENV_FILE` in your root-owned local copy if the actual deployment differs
   from the example. These values are intentionally **not read from the remote
   process environment**: the caller cannot override them. Do not place
   credentials in either value. The service user must not be able to edit the
   installed script or any parent directory.
4. Add the fixed-argv mapping from `examples/security.remote-diagnostic.yaml`
   beneath the existing `security.scripts` in the **actual active** mcp-shell
   security file. Keep the original approved scripts and preserve
   `security.enabled: true`, `writes_enabled: false`, and no unsafe-mode flag.
   Review the resulting file locally and validate the upstream version's
   configuration schema. Avoid exposing the config in issues or ChatGPT.
5. Via the authorized Linux-native admin channel, validate the actual unit,
   script executable path and permissions, then restart only the affected Tunnel
   service **after explicit operator approval**. Re-run `tunnel-client doctor`
   with the actual profile and directory. If the service fails, restore the
   host-local configuration backup and restart only that service.
6. Refresh the ChatGPT connector's tool catalog where necessary. Invoke
   `run_script(name="linux_posture")` and check the five result labels. Repeat
   `uptime`, `memory` and `disk` and one bounded typed read to detect regressions.

## Interpreting the results

- `systemd active`/`enabled`/`unprivileged service user`/`automatic restart
  policy`: PASS/FAIL from `systemctl` metadata on the connected Linux VM.
- `credential file owner/mode`: PASS/FAIL only when readable metadata for a
  regular non-symlink file is available. Missing or inaccessible metadata is
  UNVERIFIED, **not** evidence of safe permissions.
- The effective unit/stdio target, security YAML, Tunnel profile/doctor,
  firewall and reboot recovery remain UNVERIFIED until checked independently.

**Limitations:** This is a convenient host diagnostic, not self-attestation or
proof that the active Tunnel is secured. A compromised MCP host can return
false results, and the service account may lack permission to inspect some
metadata. Keep a separate Linux-native recovery path. The optional mapping is
not added to `examples/security.yaml` by default; no production deployment is
performed by merging this kit.
