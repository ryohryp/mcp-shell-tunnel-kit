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
    if "$@"; then
        printf '%s: PASS\n' "$label"
    else
        printf '%s: FAIL\n' "$label"
        result=1
    fi
}

# Avoid printing systemctl output: it can contain paths, IDs or environment values.
service_active() { systemctl is-active --quiet "$service" >/dev/null 2>&1; }
service_enabled() { systemctl is-enabled --quiet "$service" >/dev/null 2>&1; }
nonroot_service() {
    user=$(systemctl show "$service" --property=User --value 2>/dev/null) || return 1
    case "$user" in
        root) return 1 ;;
        '')
            dynamic=$(systemctl show "$service" --property=DynamicUser --value 2>/dev/null) || return 1
            [ "$dynamic" = yes ] ;;
        *) return 0 ;;
    esac
}
restart_policy() {
    policy=$(systemctl show "$service" --property=Restart --value 2>/dev/null) || return 1
    case "$policy" in
        always|on-failure) return 0 ;;
        *) return 1 ;;
    esac
}
protected_env_file() {
    # Disallow symlinks, non-files, group writes and any world access.
    [ -f "$env_file" ] && [ ! -L "$env_file" ] || return 1
    metadata=$(stat -c '%u %a' -- "$env_file" 2>/dev/null) || return 1
    set -- $metadata
    [ "$#" -eq 2 ] && [ "$1" = 0 ] || return 1
    mode=$2
    case "$mode" in
        ''|*[!0-7]*) return 1 ;;
    esac
    [ "$(( 0$mode & 0027 ))" -eq 0 ]
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
