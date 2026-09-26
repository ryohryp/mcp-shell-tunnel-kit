# GCP Compute Engine independent verification

Use this procedure to verify a deployed MCP Shell Tunnel on Google Cloud Compute Engine without relying on Remote Desktop Commander (RDC), a Windows PC, or the MCP Shell connection being tested.

## Independent administration path

Prefer an already-authorized Google Cloud path:

1. Google Cloud Console SSH-in-browser, or
2. Cloud Shell with `gcloud compute ssh`; use `--tunnel-through-iap` when IAP is the approved path.

Do not add a new public IP, open an SSH firewall rule, create long-lived SSH credentials, enable OS Login, or change IAM solely to run this verification. Those are deployment/security changes and require separate operator review.

Where OS Login is already enabled, keep using it. Google documents OS Login as IAM-backed SSH access and distinguishes the non-admin `roles/compute.osLogin` role from `roles/compute.osAdminLogin`. Use the least privilege already sufficient for the checks.

## Read-only verification

From the independently authorized VM session, use the checked-out repository copy and run:

```sh
sh scripts/verify-linux-posture.sh <actual-service-name> <actual-credential-env-file>
```

The helper emits only PASS/FAIL/UNVERIFIED posture labels. Do not paste the service name, environment-file path, host/project/instance identifiers, credentials, profile contents, private logs, or other identifying output into GitHub.

Then inspect locally, without publishing raw values:

- installed `mcp-shell` and `tunnel-client` versions against the repository's pinned examples;
- effective systemd unit and absolute stdio target;
- active security YAML: dedicated workspace scope, `security.enabled`, `writes_enabled=false`, fixed-argv approved scripts, and no unsafe mode;
- active Tunnel profile and `tunnel-client doctor`;
- relevant firewall posture and sanitized recent service health.

Record only the resulting PASS/FAIL/UNVERIFIED categories in Issue #3.

## End-to-end and reboot checks

Independently verify the ChatGPT connector can discover the MCP server and exercise only the approved read/diagnostic capabilities. Client-side success is evidence for the end-to-end path, not proof of host posture.

A reboot is a production-changing action. Perform the reboot-recovery acceptance check only after explicit operator approval. After reboot, reconnect through the independent GCP path and verify systemd recovery before repeating the approved ChatGPT-side checks.

## References

- Google Cloud: SSH-in-browser: https://cloud.google.com/compute/docs/connect/ssh-in-browser
- Google Cloud: OS Login: https://cloud.google.com/compute/docs/oslogin
- Google Cloud: SSH through IAP: https://cloud.google.com/compute/docs/connect/ssh-using-iap
