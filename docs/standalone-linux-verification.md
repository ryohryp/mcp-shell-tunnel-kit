# Standalone Linux verification (Issue #3)

This procedure verifies a Linux VM deployment **without RDC, Windows, or an always-on operator workstation**. The VM hosts both `tunnel-client` and `mcp-shell`; the Tunnel makes an outbound connection. This repository does not provide access to a VM or install the ChatGPT connector.

## 1. Prerequisites

Use an **existing, independently authorized** Linux-native administration route (SSH from any supported device, or your VM provider's console). If neither is available, mark host-side checks **unverified**; do not substitute RDC or claim service health from GitHub files. Do not copy secrets, environment files, live profiles, host identifiers, or raw private logs into issues.

Identify the *actual* unit, binary paths, profile name/directory, and workspace from the installed host. The paths in `examples/` are illustrative and must not be assumed to match a live deployment. Read-only checks require no service restart.

## 2. Host-side checks

Run commands individually on the Linux VM after checking that they match the installed service and paths:

```sh
systemctl is-active tunnel-client.service
systemctl cat tunnel-client.service
# Substitute the installed binary, profile name and directory:
tunnel-client doctor --profile <profile-name> --profile-dir <profile-dir>
# Only inspect sanitized logs locally; never post raw output to GitHub:
sudo journalctl -u tunnel-client.service -n 30 --no-pager
```

Confirm that the effective unit starts the intended stdio wrapper as an unprivileged account, has a restart policy, and references a protected credential file without exposing its contents. Check installed `mcp-shell` and `tunnel-client` versions against the README's example pins; a version mismatch is not automatically a failure, but requires upstream compatibility review.

Locally inspect the effective mcp-shell security configuration and verify the intended dedicated workspace, `security.enabled: true`, `writes_enabled: false`, and a minimal fixed-argument script allowlist. Ensure unsafe mode is not enabled. **Do not post** the actual config, profile, environment file, full process arguments, or unredacted logs. A successful systemd check does not prove end-to-end tool availability.

## 3. ChatGPT-side checks

Connect the VM-hosted Tunnel's MCP connector to the ChatGPT session. Discover the **actually exposed** tools rather than assuming the skill or template installs them. Where present, call:

1. `system_info` to confirm connectivity and the expected workspace scope.
2. A bounded typed directory/file read and a typed Git read inside the dedicated workspace (only if a suitable test repository exists).
3. `run_script` using each configured diagnostic name (`uptime`, `memory`, `disk` in the sample). Never send arbitrary shell arguments or attempt to bypass the allowlist.

Record missing tools as **unverified** or **failed**, depending on whether the connector was available and the expected tool was advertised. Do not confuse the absence of the connector with a broken VM service.

## 4. Persistence and rollback

Confirm the unit is enabled using `systemctl is-enabled tunnel-client.service`. A restart policy does not itself prove boot persistence. A VM reboot is an operational change: perform one **only after explicit operator approval**, then repeat host-side and ChatGPT-side checks. If an approved change fails, restore host-local backups as described in [operations.md](operations.md). Never restart unrelated application services.

## 5. Sanitized verification record

Record results without identifiers or sensitive output:

| Check | Result (pass/fail/unverified) | Evidence type / limitation |
| --- | --- | --- |
| Authorized Linux-native access | | |
| Installed versions reviewed | | |
| Effective unit and doctor | | |
| Dedicated workspace and security flags | | |
| Fixed diagnostic allowlist | | |
| Host-side service active | | |
| ChatGPT connector and tool discovery | | |
| Typed read tools | | |
| Allowed diagnostic scripts | | |
| Boot enablement | | |
| Approved reboot recovery (optional) | | |

Complete Issue #3 only when both host-side and ChatGPT-side checks are documented, or explicitly record access blockers. No RDC or Windows check is part of acceptance.
