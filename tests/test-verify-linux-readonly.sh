#!/bin/sh
# Offline POSIX regression tests; no real systemd service or VM required.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$script_dir/../scripts/verify-linux-readonly.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin"
printf '#!/bin/sh\nexit "${MOCK_SYSTEMCTL_EXIT:-0}"\n' > "$tmp/bin/systemctl"
chmod +x "$tmp/bin/systemctl"
printf '#!/bin/sh\nexit 0\n' > "$tmp/mcp"
chmod +x "$tmp/mcp"
printf '#!/bin/sh\nexit 0\n' > "$tmp/tunnel"
chmod +x "$tmp/tunnel"

check() {
  label=$1 expected=$2
  shift 2
  status=0
  PATH="$tmp/bin:$PATH" sh "$script" "$@" > "$tmp/output" 2>&1 || status=$?
  if [ "$status" -ne "$expected" ]; then
    printf 'FAIL %s: exit %s (expected %s)\n' "$label" "$status" "$expected" >&2
    cat "$tmp/output" >&2
    exit 1
  fi
  printf 'PASS %s\n' "$label"
}

check healthy 0 example.service "$tmp/mcp" "$tmp/tunnel"
MOCK_SYSTEMCTL_EXIT=3
export MOCK_SYSTEMCTL_EXIT
check inactive_service 1 example.service "$tmp/mcp" "$tmp/tunnel"
unset MOCK_SYSTEMCTL_EXIT
check missing_binary 1 example.service "$tmp/missing" "$tmp/tunnel"
check executable_directory_rejected 1 example.service "$tmp" "$tmp/tunnel"
check invalid_service_name 2 '../bad' "$tmp/mcp" "$tmp/tunnel"
check wrong_argument_count 2 example.service "$tmp/mcp"
