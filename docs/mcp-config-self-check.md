# Diagnose a missing MCP `run_script` entry without widening permissions

This is an **optional** self-check for the `mcp-shell` stdio process; it does not
replace an independent Linux-native management path. The key limitation is
bootstrapping: if the host has not installed and allowlisted `mcp_config_status`,
ChatGPT cannot execute it to diagnose its own absence. An unregistered
`linux_posture` is not proof that the merged PR failed or that the currently
running MCP server loaded the latest security configuration.

## Host-local preflight (no service changes)

Using the **existing authorized Linux VM** SSH/provider-console session:

1. Inspect the actual deployed `tunnel-client` unit's `ExecStart`, profile, and
   selected `mcp-shell` stdio wrapper **locally**, rather than assuming the
   repository's examples represent the live installation. Inspect the wrapper's
   `MCP_SHELL_SEC_CONFIG_FILE` setting; if it is unset or different, correct the
   active path under the existing change-control process.
2. Inspect the *real* security file at that path locally. Ensure
   `security.enabled: true`, `writes_enabled: false`, an isolated workspace,
   no unsafe-mode environment flag, and the intended fixed-argv
   `security.scripts.linux_posture` mapping. Do not paste raw files into ChatGPT
   or GitHub.
3. Verify the target `verify-linux-posture-remote.sh` **exists at the exact
   absolute path** in the real mapping, is executable, root-owned, and neither
   it nor its parent directories are writable by the MCP service account.
   The example path and `SERVICE_NAME` / `ENV_FILE` constants must be adapted
   to the real deployment. Merely merging a GitHub PR deploys nothing.
4. Review and, if desired, install the new root-owned
   `scripts/verify-mcp-config-remote.sh` at an operator-chosen absolute path,
   also outside the MCP workspace. Add the *single* fixed-argv mapping from
   `examples/security.config-self-check.yaml` beneath the real
   `security.scripts` alongside the already-approved scripts. Preserve all
   existing allowlisted entries; do not enable arbitrary shell or writes.
5. Validate the real configuration against the installed `mcp-shell` release.
   **Only after operator approval**, restart the affected Tunnel service if a
   restart is required to load it. Run `tunnel-client doctor` with the real
   profile. Keep a working independent administration route for rollback.
6. Refresh/reconnect the ChatGPT connector as needed and invoke
   `run_script(name="mcp_config_status")`, then
   `run_script(name="linux_posture")`, followed by the preexisting
   `uptime`, `memory`, and `disk` checks. Also verify a scoped typed file read.

## Bounded self-check output

`mcp_config_status` reads **only** the `MCP_SHELL_SEC_CONFIG_FILE` variable
inherited by the launched mcp-shell child process and checks that it references
an absolute, readable, regular non-symlink file. It checks whether **that
process** could write the file and looks for a `linux_posture` key in the
example YAML indentation under `security.scripts`. The output contains only
fixed labels with PASS/FAIL/UNVERIFIED or YES/NO; it never prints hostnames,
paths, usernames, YAML contents, credentials or arbitrary script names.

## Interpreting the new diagnostic reason

The helper now emits one fixed `config inspection reason` code; it never
prints the path, environment value, YAML or credentials:

| Code | Interpretation | Safe next check |
| --- | --- | --- |
| `CONFIG_ENV_UNSET` | The helper did not inherit the environment variable. | Independently inspect the live mcp-shell launch wrapper and stdio target on the VM. |
| `CONFIG_ENV_EMPTY` | The inherited variable is present but empty. | Inspect host-local wrapper configuration. |
| `CONFIG_PATH_NOT_ABSOLUTE` | The configured value is not an absolute path. | Check the active wrapper locally; do not guess a remote path. |
| `CONFIG_FILE_SYMLINK` | The inherited path is a symbolic link. | Inspect the approved host-local deployment; use a verified regular file. |
| `CONFIG_FILE_MISSING` | The inherited absolute path does not exist for this process. | Compare the host-local wrapper and deployed security-file location. |
| `CONFIG_NOT_REGULAR` | The inherited path is not a regular file. | Inspect the file type through an authorized administration channel. |
| `CONFIG_NOT_READABLE` | The helper cannot read the file. | Review owner, mode and service account locally without changing permissions broadly. |
| `CONFIG_FILE_ACCESSIBLE` | The inherited file is a readable non-symlink regular file. | Verify the effective configuration and tool registry separately. |

`CONFIG_ENV_UNSET`, `CONFIG_ENV_EMPTY` and non-absolute values result in
`UNVERIFIED`, not an assertion that the running MCP server lacks security
configuration. An observed missing/invalid/unreadable inherited file produces
`FAIL` for the file check but still does **not** establish the server's
effective loaded config. The helper's exit status remains unchanged (zero for
a completed diagnostic; two for rejected arguments); callers should interpret
its fixed output labels. In particular, fixing these conditions must not
involve making the security file world-readable or adding arbitrary shell
commands to the allowlist.

The YAML-key check is an intentionally narrow **textual inspection** for the
kit's documented formatting, not a complete YAML parser. `NO` can mean the
file uses another layout. The inherited environment value is not proof that
mcp-shell **actually parsed that file**; the effective loaded config and live
registry remain UNVERIFIED until observed through the live `run_script` calls
and separately through the operator's host-local inspection. An unset or
uninherited config variable is UNVERIFIED, not evidence that insecure mode is
running. This helper does not inspect real profiles, systemd unit contents,
firewall, credentials or Tunnel logs.

For a safe *local-only* smoke test of the helper against the intended file,
run it with a locally supplied environment variable (do not echo that value):

```sh
MCP_SHELL_SEC_CONFIG_FILE=/opt/mcp-shell/security.yaml \
  sh scripts/verify-mcp-config-remote.sh
```

This command does not prove the daemon uses that config; inspect the live
stdio command separately. No production host changes occur by merging this PR.
