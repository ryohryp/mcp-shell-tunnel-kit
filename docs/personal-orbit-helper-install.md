1	# Bounded Personal Orbit deploy-helper installation
     2	
     3	This optional capability exists only to install the reviewed Personal Orbit deployment helpers needed by the runtime-artifact migration. It is deliberately narrower than arbitrary sudo or shell access.
     4	
     5	## Boundary
     6	
     7	The MCP-visible `personal_orbit_helper_install` mapping accepts no arguments. Its installed wrapper pins the Personal Orbit repository, `origin`, `main`, and one root installer path. Before sudo it requires a clean main checkout whose HEAD exactly matches the current `origin/main`.
     8	
     9	The sudoers rule permits only:
    10	
    11	`/usr/local/sbin/install-personal-orbit-deploy-helpers`
    12	
    13	with no caller-controlled arguments. The root installer repeats the repository, branch, clean-tree, remote URL and current-origin checks before copying exactly these files:
    14	
    15	- `ops/deploy-gce.sh` -> `/usr/local/libexec/personal-orbit/deploy-gce.sh`
    16	- `ops/verify-runtime-artifact.mjs` -> `/usr/local/libexec/personal-orbit/verify-runtime-artifact.mjs`
    17	- `ops/deploy-personal-orbit` -> `/usr/local/sbin/deploy-personal-orbit`
    18	
    19	All installed files are `root:root 0755`. The installer syntax-checks the installed shell/Node helpers and does not restart a service, deploy application code, change secrets, modify IAM, or edit sudoers.
    20	
    21	## Bootstrap
    22	
    23	Enabling this capability itself changes a production authorization boundary and therefore requires an independently authorized administration path.
    24	
    25	1. Review and run `tests/test-personal-orbit-helper-install.sh`.
    26	2. Install reviewed copies of both scripts outside the MCP workspace. The MCP wrapper should be executable but non-writable by the service user. The root installer must be `root:root 0755`.
    27	3. Install the sudoers example only after replacing `mcp-shell` with the actual unprivileged service account. Validate it with `visudo -cf`; do not grant a shell, wildcard arguments, editors, package managers, service management, or general `install`/filesystem commands.
    28	4. Add the fixed-argv `personal_orbit_helper_install` mapping to the active security config.
    29	5. Restart/refresh the Tunnel through the existing administration path.
    30	6. Verify the live tool catalog exposes the named script and still exposes no arbitrary shell/sudo capability.
    31	7. Invoke it only after explicit approval for the production helper installation.
    32	
    33	## Rollback
    34	
    35	Remove the MCP mapping and sudoers entry through the independently authorized administration path and restart/refresh the Tunnel. Removing the capability does not remove already installed Personal Orbit helpers.