#!/bin/sh
# Offline POSIX tests; mocks ensure no access to a real host or credentials.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$script_dir/../scripts/verify-linux-posture.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin"
: > "$tmp/env"
cat > "$tmp/bin/systemctl" <<'MOCK'
#!/bin/sh
case "$1" in
    is-active) exit "${MOCK_ACTIVE:-0}" ;;
    is-enabled) exit "${MOCK_ENABLED:-0}" ;;
    show)
        case "$3" in
            --property=User) printf '%s\n' "${MOCK_USER-mcp-tunnel}" ;;
            --property=DynamicUser) printf '%s\n' "${MOCK_DYNAMIC-no}" ;;
            --property=Restart) printf '%s\n' "${MOCK_RESTART-always}" ;;
            *) exit 1 ;;
        esac ;;
    *) exit 1 ;;
esac
MOCK
cat > "$tmp/bin/stat" <<'MOCK'
#!/bin/sh
printf '%s\n' "${MOCK_STAT-0 600}"
MOCK
chmod +x "$tmp/bin/systemctl" "$tmp/bin/stat"
check() {
    label=$1 expected=$2
    shift 2
    status=0
    PATH="$tmp/bin:$PATH" dash "$script" "$@" > "$tmp/output" 2>&1 || status=$?
    if [ "$status" -ne "$expected" ]; then
        printf 'FAIL %s: status %s (expected %s)\n' "$label" "$status" "$expected" >&2
        cat "$tmp/output" >&2
        exit 1
    fi
    printf 'PASS %s\n' "$label"
}

check healthy 0 tunnel-client.service "$tmp/env"
MOCK_ENABLED=1; export MOCK_ENABLED
check disabled 1 tunnel-client.service "$tmp/env"
unset MOCK_ENABLED
MOCK_USER=root; export MOCK_USER
check root_user 1 tunnel-client.service "$tmp/env"
MOCK_USER=; MOCK_DYNAMIC=yes; export MOCK_DYNAMIC
check dynamic_user 0 tunnel-client.service "$tmp/env"
unset MOCK_USER MOCK_DYNAMIC
MOCK_RESTART=no; export MOCK_RESTART
check no_restart 1 tunnel-client.service "$tmp/env"
unset MOCK_RESTART
MOCK_STAT='0 644'; export MOCK_STAT
check world_readable 1 tunnel-client.service "$tmp/env"
MOCK_STAT='0 620'
check group_writable 1 tunnel-client.service "$tmp/env"
MOCK_STAT='1000 600'
check nonroot_credential_owner 1 tunnel-client.service "$tmp/env"
unset MOCK_STAT
ln -s "$tmp/env" "$tmp/link"
check symlink_rejected 1 tunnel-client.service "$tmp/link"
check missing_file 1 tunnel-client.service "$tmp/missing"
check invalid_service 2 '../bad' "$tmp/env"
check invalid_env_path 2 tunnel-client.service relative.env
check wrong_arguments 2 tunnel-client.service
if grep -F "$tmp" "$tmp/output" >/dev/null 2>&1; then
    printf '%s\n' 'FAIL usage leaks sensitive details' >&2
    exit 1
fi
MOCK_ACTIVE=3; export MOCK_ACTIVE
check inactive 1 tunnel-client.service "$tmp/env"
unset MOCK_ACTIVE
