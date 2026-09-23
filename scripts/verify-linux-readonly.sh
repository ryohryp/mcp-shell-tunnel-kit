#!/bin/sh
# Read-only Linux-side preflight for an operator-controlled host.
# Run locally on the VM; review output before sharing.
set -eu

if [ "$#" -ne 3 ]; then
  printf 'Usage: %s SERVICE_NAME MCP_SHELL_BIN TUNNEL_CLIENT_BIN\n' "$0" >&2
  exit 2
fi
service=$1
mcp_bin=$2
tunnel_bin=$3

case "$service" in
  ''|*[!a-zA-Z0-9_.@-]*) printf 'Invalid service name\n' >&2; exit 2 ;;
esac

printf '%s\n' '=== Linux-side verification (read-only) ==='
printf 'systemd service active: '
if systemctl is-active --quiet "$service" >/dev/null 2>&1; then
  printf 'PASS\n'
else
  printf 'FAIL\n'
fi

for entry in "mcp-shell:$mcp_bin" "tunnel-client:$tunnel_bin"; do
  label=${entry%%:*}
  path=${entry#*:}
  if [ -x "$path" ]; then
    printf '%s executable: PASS\n' "$label"
  else
    printf '%s executable: FAIL\n' "$label"
  fi
done

printf '%s\n' '=== Operator-only follow-up ==='
printf '%s\n' 'Inspect the active unit, security config, profile and sanitized logs manually.'
printf '%s\n' 'Do not share raw output, paths, account names, credentials or host identifiers.'
printf '%s\n' 'Run tunnel-client doctor separately with the actual profile; sanitize results.'
printf '%s\n' 'A PASS here does not establish that ChatGPT tools are reachable.'
