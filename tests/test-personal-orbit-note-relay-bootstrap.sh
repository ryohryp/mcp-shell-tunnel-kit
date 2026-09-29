#!/bin/sh
set -eu

W="scripts/bootstrap-personal-orbit-note-relay.sh"
R="scripts/bootstrap-personal-orbit-note-relay-root.sh"
C="examples/security-development.yaml"
S="examples/sudoers-personal-orbit-note-relay-bootstrap"

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

for script in "$W" "$R"; do
  dash -n "$script" || fail "shell syntax invalid: $script"
  grep -F '[ "$#" -eq 0 ]' "$script" >/dev/null || fail "arguments must be rejected: $script"
  if grep -E 'sh -c|bash -c|eval ' "$script" >/dev/null; then
    fail "shell escape present: $script"
  fi
done

grep -F 'ROOT_INSTALLER="/usr/local/sbin/bootstrap-personal-orbit-note-relay"' "$W" >/dev/null   || fail "MCP wrapper root installer is not pinned"
grep -F 'exec sudo -- "$ROOT_INSTALLER"' "$W" >/dev/null   || fail "MCP wrapper fixed sudo invocation missing"

grep -F 'REPO="/home/ryohryp/personal-orbit"' "$R" >/dev/null || fail "Personal Orbit repo is not pinned"
grep -F 'SOURCE_PATH="ops/bootstrap-note-publication-relay-ops"' "$R" >/dev/null   || fail "Personal Orbit reviewed bootstrap source is not pinned"
grep -F 'TARGET_BOOTSTRAP="/usr/local/sbin/bootstrap-note-publication-relay-ops"' "$R" >/dev/null   || fail "Personal Orbit bootstrap target is not pinned"
grep -F 'fetch --no-tags "$REMOTE" "refs/heads/main:$SOURCE_REF"' "$R" >/dev/null   || fail "current origin/main fetch is missing"
grep -F 'show "$source_sha:$SOURCE_PATH"' "$R" >/dev/null   || fail "reviewed bootstrap is not extracted from the verified SHA"
grep -F '"$TARGET_BOOTSTRAP" "$source_sha"' "$R" >/dev/null   || fail "reviewed bootstrap is not invoked with the verified SHA"
grep -F 'rm -f -- "$SELF_SUDOERS"' "$R" >/dev/null   || fail "one-time sudoers cleanup missing"
grep -F 'rm -f -- "$SELF_PATH"' "$R" >/dev/null   || fail "one-time root installer cleanup missing"

if grep -E 'systemctl|NOTE_PUBLICATION_V3_RELAY_MODE|configure-note-publication-relay[[:space:]]+(off|poll)|sudo[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*[^"]' "$R" >/dev/null; then
  fail "root bootstrap contains an unrelated execution/configuration surface"
fi

grep -F 'personal_orbit_note_relay_bootstrap:' "$C" >/dev/null || fail "MCP mapping missing"
grep -F 'NOPASSWD: /usr/local/sbin/bootstrap-personal-orbit-note-relay' "$S" >/dev/null   || fail "sudoers command not fixed"
if grep -E 'NOPASSWD:.*\*|/bin/(ba)?sh|ALL[[:space:]]*=' "$S" >/dev/null; then
  fail "sudoers example too broad"
fi

printf '%s\n' "PASS: Personal Orbit note relay bootstrap static policy checks"
