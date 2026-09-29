# Bounded Personal Orbit note relay bootstrap

This optional capability exists only to install Personal Orbit's reviewed, bounded note publication relay configuration operation. It does **not** enable the relay, restart Personal Orbit, publish a note, deploy application code, or read credentials.

## Boundary

The MCP-visible `personal_orbit_note_relay_bootstrap` mapping accepts no arguments and invokes only the root-owned `/usr/local/sbin/bootstrap-personal-orbit-note-relay` installer.

The root installer:

1. pins `/home/ryohryp/personal-orbit` and the expected GitHub origin;
2. fetches only `origin/main` as the unprivileged `ryohryp` deploy user;
3. requires that fetched main to equal the exact Personal Orbit SHA approved for this one-time bootstrap (`4ab8ffc4e188b4dd174227779337d4a5d585c3f2`);
4. extracts exactly `ops/bootstrap-note-publication-relay-ops` from that approved Git object;
5. syntax-checks and installs that reviewed bootstrap temporarily as `root:root 0755`;
6. invokes it with the exact fetched SHA;
7. requires the Personal Orbit bootstrap to self-remove after success; and
8. removes its own one-time root installer and sudoers entry after success.

The called Personal Orbit bootstrap owns installation and verification of the fixed relay wrapper/helper and its two exact `off` / `poll` sudo grants. This MCP capability never chooses either mode.

## Bootstrap

Enabling this capability changes the live MCP authorization boundary and cannot be bootstrapped by the live MCP connection itself.

1. Review and run `tests/test-personal-orbit-note-relay-bootstrap.sh`.
2. Install reviewed copies of:
   - `scripts/bootstrap-personal-orbit-note-relay.sh` at a non-writable fixed path available to the MCP service account;
   - `scripts/bootstrap-personal-orbit-note-relay-root.sh` as `/usr/local/sbin/bootstrap-personal-orbit-note-relay`, `root:root 0755`.
3. Install the sudoers example after replacing `mcp-shell` with the actual unprivileged MCP service account; validate with `visudo -cf`.
4. Add the fixed-argv `personal_orbit_note_relay_bootstrap` mapping to the active security config.
5. Restart/refresh only the Tunnel through an independently authorized administration path.
6. Verify the live tool catalog exposes the new script and still exposes no arbitrary shell or caller-controlled sudo command.
7. Invoke it only after explicit production approval.

After a successful invocation, the one-time root installer and its sudoers entry are removed automatically. Relay mode remains unchanged; enabling `poll` is a separate Personal Orbit production configuration action.

If Personal Orbit `main` moves away from the pinned approved SHA before this capability is invoked, the installer fails closed. Update/re-review this one-time capability instead of silently accepting a newer main commit.
