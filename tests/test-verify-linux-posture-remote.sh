#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$here/../scripts/verify-linux-posture-remote.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin"
: > "$tmp/credentials"
cat > "$tmp/bin/systemctl" <<'SH'
#!/bin/sh
case "$1" in
  is-active) exit "${ACTIVE_EXIT:-0}" ;;
  is-enabled) exit "${ENABLED_EXIT:-0}" ;;
  show)
    case "$3" in
      --property=User) printf '%s\n' "${UNIT_USER-mcp-tunnel}" ;;
      --property=DynamicUser) printf '%s\n' "${DYNAMIC_USER-no}" ;;
      --property=Restart) printf '%s\n' "${RESTART_POLICY-always}" ;;
      *) exit 1 ;;
    esac ;;
  *) exit 1 ;;
esac
SH
cat > "$tmp/bin/stat" <<'SH'
#!/bin/sh
printf '%s\n' "${STAT_RESULT-0 600}"
SH
chmod +x "$tmp/bin/systemctl" "$tmp/bin/stat"
# Test the fixed command path against mock binaries without host access.
sed -e "s|^PATH=/usr/sbin:/usr/bin:/sbin:/bin$|PATH=$tmp/bin:/usr/sbin:/usr/bin:/sbin:/bin|" -e "s|^ENV_FILE=/etc/tunnel-client/runtime.env$|ENV_FILE=$tmp/credentials|" "$script" > "$tmp/script"
result() {
  name=$1
  pattern=$2
  /bin/sh "$tmp/script" > "$tmp/output"
  if ! grep -Fq "$pattern" "$tmp/output"; then
    printf 'FAIL %s expected %s\n' "$name" "$pattern" >&2
    cat "$tmp/output" >&2
    exit 1
  fi
  if grep -Fq "$tmp" "$tmp/output"; then
    printf 'FAIL %s leaked a path\n' "$name" >&2
    exit 1
  fi
  printf 'PASS %s\n' "$name"
}
result healthy 'systemd active: PASS'
ACTIVE_EXIT=3; export ACTIVE_EXIT
result inactive 'systemd active: FAIL'
unset ACTIVE_EXIT
ENABLED_EXIT=1; export ENABLED_EXIT
result disabled 'systemd enabled at boot: FAIL'
unset ENABLED_EXIT
UNIT_USER=root; export UNIT_USER
result root 'unprivileged service user: FAIL'
UNIT_USER=; DYNAMIC_USER=yes; export DYNAMIC_USER
result dynamic 'unprivileged service user: PASS'
unset UNIT_USER DYNAMIC_USER
RESTART_POLICY=no; export RESTART_POLICY
result no_restart 'automatic restart policy: FAIL'
unset RESTART_POLICY
STAT_RESULT='0 644'; export STAT_RESULT
result world_readable 'credential file owner/mode: FAIL'
STAT_RESULT='0 620'
result group_writable 'credential file owner/mode: FAIL'
STAT_RESULT='1000 600'
result nonroot_owner 'credential file owner/mode: FAIL'
unset STAT_RESULT
sed "s|^ENV_FILE=$tmp/credentials$|ENV_FILE=$tmp/missing|" "$tmp/script" > "$tmp/missing-script"
/bin/sh "$tmp/missing-script" > "$tmp/output"
grep -Fq 'credential file owner/mode: UNVERIFIED' "$tmp/output"
printf '%s\n' 'PASS missing credential file'
ln -s "$tmp/credentials" "$tmp/link"
sed "s|^ENV_FILE=$tmp/credentials$|ENV_FILE=$tmp/link|" "$tmp/script" > "$tmp/link-script"
/bin/sh "$tmp/link-script" > "$tmp/output"
grep -Fq 'credential file owner/mode: UNVERIFIED' "$tmp/output"
printf '%s\n' 'PASS symlink credential file'
sed "s|^SERVICE_NAME=tunnel-client.service$|SERVICE_NAME=../unsafe|" "$tmp/script" > "$tmp/unsafe-script"
/bin/sh "$tmp/unsafe-script" > "$tmp/output"
grep -Fq 'systemd active: FAIL' "$tmp/output"
printf '%s\n' 'PASS unsafe service name'
status=0
/bin/sh "$tmp/script" extra > "$tmp/output" 2>&1 || status=$?
[ "$status" -eq 2 ]
printf '%s\n' 'PASS no arbitrary arguments'
