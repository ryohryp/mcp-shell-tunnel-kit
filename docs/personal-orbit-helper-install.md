# Bounded Personal Orbit deploy-helper installation

This optional capability installs reviewed Personal Orbit deployment helpers and can bootstrap one fixed GCE Tunnel restart operation. It accepts no arguments and is deliberately narrower than arbitrary sudo or shell access.

## Boundary

When explicitly enabled in the active MCP security configuration, the optional `personal_orbit_helper_install` mapping invokes a root-owned wrapper outside the MCP workspace. That wrapper accepts no arguments and runs only the fixed root installer with non-interactive sudo. This repository change does not enable or refresh the live mapping. The MCP account does not need read access to the private application checkout; the root installer performs every repository check through the pinned application account before it reads source files.

The sudoers command specification uses `""` to permit only an invocation with no arguments:

`/usr/local/sbin/install-personal-orbit-deploy-helpers ""`

with no caller-controlled arguments. The root installer checks the repository owner, a clean worktree, and the exact GitHub SSH origin. It accepts the deployed checkout's detached HEAD or the `main` branch, and rejects other branches. It fetches only `refs/heads/main` into `refs/remotes/origin/main` as the unprivileged repository owner, confirms that the checkout commit is an ancestor of the fetched main SHA and that the remote SHA did not move, and verifies that the application checkout HEAD and worktree remain unchanged. It reads reviewed files from that exact Git object; it does not check out or deploy the application.

The same fixed no-argument root installer also runs the one-time Tunnel delegation bootstrap from `ops/bootstrap-gce-tunnel-ops-delegation` at that reviewed SHA. The nested bootstrap installs only the root-owned fixed Tunnel restart wrapper and the production runner's exact no-argument sudoers grant, validates `visudo`, and removes its temporary bootstrap path on success. It does not restart the Tunnel or Personal Orbit service, deploy the app, change secrets, modify IAM, or grant general sudo. If bootstrap installation fails, it restores the previous Tunnel wrapper and sudoers state; the outer installer removes the temporary bootstrap executable. The pre-existing deployment helpers may already have been refreshed from the same reviewed SHA before a bootstrap failure.

The existing deploy-helper files are also installed from the same reviewed Git object:

- `ops/deploy-gce.sh` -> `/usr/local/libexec/personal-orbit/deploy-gce.sh`
- `ops/verify-runtime-artifact.mjs` -> `/usr/local/libexec/personal-orbit/verify-runtime-artifact.mjs`
- `ops/deploy-personal-orbit` -> `/usr/local/sbin/deploy-personal-orbit`

Installed helper executables and the Tunnel wrapper are `root:root 0755`; the sudoers entry is `root:root 0440`. The installer syntax-checks the installed shell/Node helpers. Its only sudoers change is the inner bootstrap's exact, no-argument Tunnel restart grant; it does not restart a service, deploy application code, change secrets, or modify IAM.

## Bootstrap

Enabling this capability itself changes a production authorization boundary and therefore requires an independently authorized administration path. The existing root-owned installer does not update itself: after reviewing and merging a change to this source, replacing `/usr/local/sbin/install-personal-orbit-deploy-helpers` still requires the already-authorized host administration path. Invoking the currently installed older copy cannot activate a source change that it does not contain.

1. Review and run `tests/test-personal-orbit-helper-install.sh`.
2. Install reviewed copies of both scripts outside the MCP workspace. The MCP wrapper should be `root:root 0755`; the root installer must also be `root:root 0755`.
3. Install the sudoers example only after replacing `mcp-shell` with the actual unprivileged service account. Validate it with `visudo -cf`, then inspect effective privileges with `sudo -l` for that account. If another included rule grants broader sudo, add a later host-owned rule that revokes it before granting only this argumentless installer. Do not grant a shell, wildcard arguments, editors, package managers, service management, or general `install`/filesystem commands.
4. Add the fixed-argv `personal_orbit_helper_install` mapping to the active security config.
5. Restart/refresh the Tunnel through the existing administration path.
6. Verify the live tool catalog exposes the named script and still exposes no arbitrary shell/sudo capability.
7. Invoke it only after explicit approval for the production helper installation.

## Rollback

For the Tunnel delegation, use the independently authorized administration path to remove only `/etc/sudoers.d/personal-orbit-gce-tunnel-restart` and `/usr/local/sbin/restart-gce-tunnel-client`, then validate the remaining sudoers configuration with `visudo -c`. If the optional MCP mapping was enabled, remove that mapping and refresh the Tunnel through its existing administration path. This does not remove the separate Personal Orbit deploy helpers.
