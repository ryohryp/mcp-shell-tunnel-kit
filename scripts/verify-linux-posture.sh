#!/bin/sh
# Sanitized read-only checks for a Linux systemd Tunnel deployment.
# Run through an independently authorized Linux-native admin channel.
# This script does not read or print credential or profile contents.
set -eu

if [ "$#" -ne 2 ]; then
    printf 'Usage: %s SERVICE_NAME ENV_FILE\n' "$0" >&2
    exit 2
fi
service=$1
env_file=$2
case "$service" in
    ''|*[!a-zA-Z0-9_.@-]*) printf 'Invalid service name\n' >&2; exit 2 ;;
esac
case "$env_file" in
    /*) ;;
    *) printf 'ENV_FILE must be an absolute path\n' >&2; exit 2 ;;
esac

result=0
check() {
    label=$1
    shift
    status=0
    "$@" || status=$?
    case "$status" in
        0) printf '%s: PASS\n' "$label" ;;
        1) printf '%s: FAIL\n' "$label"; result=1 ;;
        *) printf '%s: UNVERIFIED\n' "$label"; [ "$result" -eq 1 ] || result=2 ;;
    esac
}

# Exit 1 means an observed policy violation; exit 2 means insufficient evidence.
# Avoid printing systemctl output: it can contain paths, IDs or environment values.
systemctl_available() { command -v systemctl >/dev/null 2>&1 || return 2; }
service_property() {
    systemctl_available || return 2
    value=$(systemctl show "$service" "--property=$1" --value 2>/dev/null) || return 2
    [ -n "$value" ] || return 2
    printf '%s\n' "$value"
}
service_active() {
    systemctl_available || return 2
    state=$(systemctl is-active "$service" 2>/dev/null) || :
    case "$state" in active) return 0 ;; inactive|failed|deactivating) return 1 ;; *) return 2 ;; esac
}
service_enabled() {
    systemctl_available || return 2
    state=$(systemctl is-enabled "$service" 2>/dev/null) || :
    case "$state" in enabled|enabled-runtime) return 0 ;; disabled|masked|masked-runtime) return 1 ;; *) return 2 ;; esac
}
nonroot_service() {
    systemctl_available || return 2
    user=$(systemctl show "$service" --property=User --value 2>/dev/null) || return 2
    case "$user" in
        root) return 1 ;;
        '')
            dynamic=$(service_property DynamicUser) || return 2
            case "$dynamic" in yes) return 0 ;; no) return 1 ;; *) return 2 ;; esac ;;
        *) return 0 ;;
    esac
}
restart_policy() {
    policy=$(service_property Restart) || return 2
    case "$policy" in
        always|on-failure) return 0 ;;
        no|on-success|on-abnormal|on-abort|on-watchdog) return 1 ;;
        *) return 2 ;;
    esac
}
protected_env_file() {
    # Disallow symlinks, non-files, group writes and any world access.
    [ ! -L "$env_file" ] || return 1
    [ -e "$env_file" ] || return 2
    [ -f "$env_file" ] || return 1
    metadata=$(stat -c '%u %a' -- "$env_file" 2>/dev/null) || return 2
    set -- $metadata
    [ "$#" -eq 2 ] || return 2
    [ "$1" = 0 ] || return 1
    mode=$2
    case "$mode" in
        ''|*[!0-7]*) return 1 ;;
    esac
    [ "$(( 0$mode & 0077 ))" -eq 0 ]
}

printf '%s\n' '=== Sanitized Linux Tunnel posture (read-only) ==='
check 'systemd active' service_active
check 'systemd enabled at boot' service_enabled
check 'unprivileged service user' nonroot_service
check 'automatic restart policy' restart_policy
check 'credential file owner/mode' protected_env_file
printf '%s\n' '=== Not established by this check ==='
printf '%s\n' 'Effective stdio command, active profile, security YAML, firewall, unsafe inherited environment, logs and Tunnel doctor: UNVERIFIED'
printf '%s\n' 'Service recovery after reboot and ChatGPT end-to-end execution: UNVERIFIED'
printf '%s\n' 'Inspect these separately on the VM; never publish raw secrets or profiles.'
exit "$result"
