#!/bin/sh
# Read-only, no-argument MCP diagnostic. Bound to an operator-approved service and
# environment-file path at deployment, not controlled by the remote caller.
set -u
if [ "$#" -ne 0 ]; then
  printf "%s\n" "diagnostic arguments are not accepted"
  exit 2
fi
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
LC_ALL=C
export LC_ALL
SERVICE_NAME=tunnel-client.service
ENV_FILE=/etc/tunnel-client/runtime.env
# Override these two constants in the root-owned installed copy after reviewing
# the actual systemd unit. Never take service names or file paths from callers.

case "$SERVICE_NAME" in
  ''|*[!a-zA-Z0-9_.@-]*) SERVICE_VALID=0 ;;
  *) SERVICE_VALID=1 ;;
esac
case "$ENV_FILE" in
  /*) ENV_VALID=1 ;;
  *) ENV_VALID=0 ;;
esac

check() {
  label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    printf '%s: PASS\n' "$label"
  else
    printf '%s: FAIL\n' "$label"
  fi
}
service_active() { [ "$SERVICE_VALID" -eq 1 ] && systemctl is-active --quiet "$SERVICE_NAME"; }
service_enabled() { [ "$SERVICE_VALID" -eq 1 ] && systemctl is-enabled --quiet "$SERVICE_NAME"; }
service_nonroot() {
  [ "$SERVICE_VALID" -eq 1 ] || return 1
  user=$(systemctl show "$SERVICE_NAME" --property=User --value 2>/dev/null) || return 1
  case "$user" in
    root) return 1 ;;
    '') [ "$(systemctl show "$SERVICE_NAME" --property=DynamicUser --value 2>/dev/null)" = yes ] ;;
    *) return 0 ;;
  esac
}
service_restart() {
  [ "$SERVICE_VALID" -eq 1 ] || return 1
  case "$(systemctl show "$SERVICE_NAME" --property=Restart --value 2>/dev/null)" in
    always|on-failure) return 0 ;;
    *) return 1 ;;
  esac
}
file_mode() {
  [ "$ENV_VALID" -eq 1 ] && [ -f "$ENV_FILE" ] && [ ! -L "$ENV_FILE" ] || return 1
  metadata=$(stat -c '%u %a' -- "$ENV_FILE" 2>/dev/null) || return 1
  set -- $metadata
  [ "$#" -eq 2 ] && [ "$1" = 0 ] || return 1
  mode=$2
  case "$mode" in
    ''|*[!0-7]*) return 1 ;;
  esac
  [ "$((0$mode & 0027))" -eq 0 ]
}

printf '%s\n' '=== Linux Tunnel read-only diagnostic ==='
check 'systemd active' service_active
check 'systemd enabled at boot' service_enabled
check 'unprivileged service user' service_nonroot
check 'automatic restart policy' service_restart
if [ "$ENV_VALID" -eq 1 ] && [ -f "$ENV_FILE" ] && [ ! -L "$ENV_FILE" ] && stat -c '%u %a' -- "$ENV_FILE" >/dev/null 2>&1; then
  check 'credential file owner/mode' file_mode
else
  printf '%s\n' 'credential file owner/mode: UNVERIFIED'
fi
printf '%s\n' 'Actual effective unit, security YAML, Tunnel profile/doctor, firewall and reboot recovery: UNVERIFIED'
