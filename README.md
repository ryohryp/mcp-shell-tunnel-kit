# MCP Shell Tunnel Kit

A reusable Linux VM deployment kit for running [mcp-shell](https://github.com/sonirico/mcp-shell) behind the [OpenAI Secure MCP Tunnel](https://github.com/openai/tunnel-client).

This repository contains **configuration templates and operational instructions**, not a fork of either upstream project. The initial example pins `mcp-shell v1.0.0` and `tunnel-client v0.0.14`. Check the upstream documentation and release artifacts before installing or upgrading.

## What it provides

- Secure-mode MCP file and Git inspection tools scoped to a dedicated workspace.
- Opt-in, **operator-defined** diagnostic commands via `run_script` (`uptime`, `free -h`, `df -h`).
- An outbound Tunnel running as a systemd service, using a separate environment file for credentials.
- A verification and rollback checklist for changing an existing installation.

`run_script` is *not* an arbitrary shell: callers select a preconfigured script name and cannot replace its arguments. The sample keeps `writes_enabled: false` and does **not** enable `MCP_SHELL_ALLOW_UNSAFE`.

## Architecture

```text
ChatGPT
  |
OpenAI Secure MCP Tunnel
  |
tunnel-client (systemd, unprivileged user)
  | stdio
mcp-shell (secure mode)
  |- typed file / Git read tools -> dedicated workspace
  '- run_script: uptime, memory, disk
```

The Tunnel connects to an operator-managed local MCP target; you do not need to expose an inbound MCP port on the VM.

## Quick start

1. Follow upstream instructions to install the pinned [mcp-shell v1.0.0](https://github.com/sonirico/mcp-shell/tree/v1.0.0) and [tunnel-client v0.0.14](https://github.com/openai/tunnel-client/tree/v0.0.14) on a Linux VM. Verify release artifacts independently.
2. Create an unprivileged service user, a dedicated workspace and an application directory. Copy [`examples/security.yaml`](examples/security.yaml) and replace the workspace path with your dedicated absolute path.
3. Set `MCP_SHELL_SEC_CONFIG_FILE` to the installed security file. Use `examples/run-mcp-shell-secure.sh` as the local stdio MCP command; adjust `MCP_SHELL_BIN` as appropriate.
4. Create your own Tunnel profile using the upstream tooling. Bind the `main` MCP channel to the wrapper's **absolute** path; see [`examples/tunnel-profile.yaml`](examples/tunnel-profile.yaml) for a *partial example*, not a full drop-in profile. Keep your real tunnel ID and credentials outside Git.
5. Adapt [`examples/tunnel-client.service`](examples/tunnel-client.service) to your installation paths, service user and profile. Put credentials in a root-controlled environment file (mode `0600`); never store it in this repository.
6. Run `tunnel-client doctor --profile <name> --profile-dir <path>` using your installed release, then follow [`docs/operations.md`](docs/operations.md) to validate, start and test the service.

For native commands and the full Tunnel profile schema, always use [upstream configuration documentation](https://github.com/openai/tunnel-client/blob/v0.0.14/docs/configuration.md).

## Scope and security

This kit **does not guarantee** that a server is secure. Any script exposed to an AI client is remote command execution, even if it is named and preconfigured. Review all changes to `scripts` carefully; avoid shells, interpreters, package managers, arbitrary file parameters and commands that can mutate state. File/Git read tools can expose sensitive material *inside* the configured workspace, so keep that workspace free of secrets and unrelated repositories.

Never commit real profiles, API keys, credential files, tunnel IDs, hostnames, private IPs, production paths, private logs or backups. The files in `examples/` use synthetic placeholders. Review [`docs/operations.md`](docs/operations.md) before modifying a live VM.

## Upstream and attribution

- [sonirico/mcp-shell](https://github.com/sonirico/mcp-shell/tree/v1.0.0) — MCP server and `run_script`.
- [openai/tunnel-client](https://github.com/openai/tunnel-client/tree/v0.0.14) — Secure MCP Tunnel client and systemd deployment pattern.

No upstream code or binaries are vendored. Refer to each upstream repository for its own license and security policy.
