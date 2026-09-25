# ChatGPT-side MCP verification (Issue #3)

This checklist records **client-visible behavior only**. It does not attest to the live host's systemd configuration, active security file, Tunnel profile, or restart behavior. Do not include hostnames, account names, private workspace paths, raw logs, or credentials in public reports.

## Reproducible checks

From a ChatGPT conversation with the MCP Shell Tunnel connector available:

| Check | Expected result | Observation on 2026-09-23 (UTC) |
| --- | --- | --- |
| Discover connector | `system_info`, typed read tools and approved scripts are exposed | PASS |
| `system_info` | Returns Linux platform and workspace metadata | PASS; Linux/amd64; no Git root in the fixture |
| `run_script(name="uptime")` | Approved script executes | PASS |
| `read_file(path="README.txt")` | Fixture text is readable | PASS; read-only fixture |
| `stat(path="../")` | Workspace traversal is rejected | PASS; escaped workspace rejected |
| `git_status()` | Succeeds only when workspace is a Git repository | EXPECTED LIMITATION; fixture has no Git repository |

Avoid using a Git failure in the fixture as evidence of a broken Tunnel or Git tool. Run Git-read checks separately against an explicitly approved workspace containing a test repository; do not widen access to unrelated repositories.

## Still unverified

- Inspect **actual** deployed security settings (`security.enabled`, `writes_enabled=false`, allowlisted fixed-argv scripts, unsafe mode disabled), without disclosing secrets.
- Inspect the live systemd unit and stdio target using an independently authorized Linux-native administration path.
- Run `tunnel-client doctor` with the actual local profile and verify sanitized service health and logs.
- Test Git reads in a dedicated, non-sensitive Git fixture.
- With operator approval, test service recovery after an approved VM reboot; verify ChatGPT-side tool discovery again.

This evidence supports only the checks listed as PASS. A successful client-side traversal rejection does not independently prove every possible filesystem boundary or the complete host configuration. Do not perform service restarts or production configuration changes as part of this checklist.

## Bounded development workspace E2E verification (2026-09-24 UTC)

After the opt-in development profile was applied and the ChatGPT connector catalog was refreshed, the client exposed the typed write and bounded Git tools expected from mcp-shell with `writes_enabled: true`.

The following checks were performed against the dedicated Git workspace:

| Check | Expected result | Observation |
| --- | --- | --- |
| Tool discovery after connector refresh | Typed write/edit/delete and bounded Git tools are visible | PASS |
| Create disposable file with `write_file` | File is created inside the workspace | PASS |
| Read created file | Written content is returned | PASS |
| Update disposable file with `edit_file` | Exact replacement succeeds | PASS |
| Delete disposable file | File is removed | PASS |
| Read/stat after deletion | File no longer exists | PASS |
| Read `../...` outside workspace | Traversal is rejected | PASS; escaped workspace rejected |
| `run_script(name="git_status")` | Fixed-argv validation command runs | PASS; clean branch reported |
| `run_script(name="git_diff_check")` | Fixed-argv validation command runs without diff errors | PASS |

The first connector view continued to expose the previous read-only catalog even though a direct `tools/list` against mcp-shell already included the write tools. Restarting the Tunnel alone did not update the ChatGPT-visible catalog. Refreshing the connector caused the new tool schema to appear. This distinguishes host-side mcp-shell registration from client-side connector catalog refresh.

No arbitrary shell, `sudo`, package-manager, service-management, credential-management, or deployment capability was added. The disposable test file was deleted and the repository was clean after verification.
