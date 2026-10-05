# Bounded Personal Orbit runtime-artifact bootstrap

This optional capability exists only to apply Personal Orbit's reviewed protected-runtime bootstrap from the current `main` revision. It is narrower than the existing broader helper installer because it does not install the Tunnel restart wrapper or any unrelated helper.

## Boundary

The MCP-visible `personal_orbit_runtime_artifact_bootstrap` mapping accepts no arguments and invokes only:

`/usr/local/sbin/bootstrap-personal-orbit-runtime-artifact`

through non-interactive sudo.

The root bootstrap:

- pins the Personal Orbit repository to `/home/ryohryp/personal-orbit`;
- runs Git checks as the repository owner `ryohryp`;
- requires a clean detached/main checkout that is an ancestor of the freshly fetched `origin/main`;
- rechecks the exact GitHub SSH origin and confirms `origin/main` did not move;
- extracts only `ops/bootstrap-gce-runtime-artifact` from that exact main Git object;
- stages it temporarily as root-owned `/usr/local/sbin/bootstrap-gce-runtime-artifact`;
- executes it with the exact reviewed 40-character main SHA;
- requires the nested bootstrap to remove its temporary fixed path.

The capability does not restart the Tunnel or Personal Orbit, deploy application code by itself, change secrets, modify IAM, install package managers, or expose arbitrary shell/sudo execution.

## Host bootstrap

Enabling this capability changes a production authorization boundary. The live Tunnel must not edit or restart its own security policy. Use an independently authorized host administration path to:

1. install reviewed copies of `scripts/bootstrap-personal-orbit-runtime-artifact.sh` and `scripts/bootstrap-personal-orbit-runtime-artifact-root.sh` outside the MCP workspace;
2. install the exact no-argument sudoers grant from `examples/sudoers-personal-orbit-runtime-artifact-bootstrap`, replacing the example principal with the actual unprivileged Tunnel account;
3. validate the rule with `visudo -cf` and inspect effective privileges;
4. add the fixed-argv `personal_orbit_runtime_artifact_bootstrap` mapping to the active security config;
5. restart/refresh only the Tunnel through the existing administration path;
6. verify the live tool catalog exposes the new script and still exposes no arbitrary shell/sudo capability.

After that bootstrap, invoking the capability remains a production authorization action and still requires explicit operator approval.

## Rollback

Remove the mapping and its dedicated sudoers entry through the independent administration path, then refresh the Tunnel. Removing the capability does not undo runtime-artifact files already installed by the Personal Orbit bootstrap.
