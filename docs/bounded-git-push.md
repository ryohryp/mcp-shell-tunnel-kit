# Bounded Git push

Secure mode in upstream mcp-shell intentionally does not expose network Git operations such as push, fetch or clone. This kit keeps that boundary intact. When an operator explicitly needs publication of already-reviewed local commits, `scripts/bounded-git-push.sh` provides a separate opt-in fixed-argv capability.

## Security boundary

The wrapper accepts no arguments. A reviewed installed copy pins:

- one repository path;
- one remote name (default example: `origin`);
- an explicit branch allowlist.

It rejects detached HEAD and branches outside the allowlist, validates that the configured remote resolves to a GitHub HTTPS or SSH URL, and invokes only a normal non-force push of the current HEAD to the same branch. It provides no caller-controlled remote, URL, refspec, force flag or extra Git arguments.

This is still an external side effect. Do not enable it merely because `writes_enabled: true` is enabled.

## Installation

1. Review `scripts/bounded-git-push.sh` and run `tests/test-bounded-git-push.sh`.
2. Copy the wrapper outside the MCP workspace to an operator-controlled location such as `/opt/mcp-shell-tunnel-kit/scripts/bounded-git-push.sh`.
3. Edit the installed copy to pin the actual dedicated repository, approved remote and allowed branches.
4. Make the installed wrapper and every parent directory non-writable by the Tunnel/MCP service user.
5. Configure Git authentication independently of the MCP workspace. Never store tokens, SSH private keys or credential files in the repository.
6. Add only the fixed-argv `git_push_bounded` mapping shown in `examples/security-development.yaml`.
7. Restart/refresh the connector only through the separately authorized administration path, then verify the resulting tool catalog still exposes no arbitrary shell or service-management capability.

## Verification

Use a disposable approved branch first. Confirm a normal fast-forward push succeeds. Then verify that a detached HEAD and a non-allowlisted branch are rejected. Because the MCP mapping accepts no arguments, callers cannot select another remote, provide an arbitrary refspec, or request force push.

Also confirm the configured repository remains the dedicated MCP workspace and that credentials stay outside it. A push failure must be reported as a failure; do not add an unsafe fallback.

## Rollback

Remove the `git_push_bounded` mapping from the active host-local security configuration and restart the Tunnel through the normal operator-approved administration path. The typed workspace write tools can remain enabled independently.
