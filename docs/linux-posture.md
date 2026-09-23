# Sanitized systemd and credential-file posture check

For Issue #3, use an **independently authorized Linux-native** administration path (SSH or VM provider console), without RDC or Windows. The script is deliberately **not** registered as an MCP `run_script`: a broken Tunnel must remain diagnosable independently of that Tunnel, and publishing host metadata to the AI client is unnecessary.

From a trusted local checkout, review `scripts/verify-linux-posture.sh`, then run it with the **actual** deployed systemd service name and the path of its existing credential *environment file* (not the security YAML or Tunnel profile):

```sh
sh scripts/verify-linux-posture.sh tunnel-client.service /etc/tunnel-client/runtime.env
```

It performs only read-only checks, returns `0` if all checks pass, `1` if a check fails, or `2` for invalid input, and emits PASS/FAIL results without printing service usernames, filesystem paths, file contents or raw systemd properties:

- Service is active and enabled at boot.
- Service uses a non-root `User=` or `DynamicUser=yes` rather than the default root account.
- Service uses `Restart=always` or `Restart=on-failure`.
- The specified credential environment file is a regular non-symlink file owned by root, with no group write or world permissions (e.g., `0600` or `0640`). The script does **not** infer that the specified file is referenced by the actual unit.

A PASS does **not** prove that the service executed the intended stdio wrapper, that a credential file is referenced by the actual unit, that its parent directories are protected, or that a live profile, security YAML or firewall is correctly configured. On the host, separately inspect the effective unit, actual security config, fixed-argv script list, inherited unsafe-mode settings, and `tunnel-client doctor`; sanitize any results before sharing. In particular confirm `security.enabled: true`, `writes_enabled: false`, and dedicated workspace scoping. To avoid leaking private data, do **not** upload raw `systemctl show`/`systemctl cat`, `journalctl`, doctor output, real profiles or environment file contents to GitHub.

This script makes no modifications, does not restart services, and does not replace the end-to-end ChatGPT-side connector checks described in `chatgpt-verification.md`. Only test VM reboot persistence after explicit operator approval. Keep private installation results off the public repository; a public issue should contain only sanitized pass/fail/unverified observations.
