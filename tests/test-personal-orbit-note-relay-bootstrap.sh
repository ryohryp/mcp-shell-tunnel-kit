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
grep -F 'SUDO="/usr/bin/sudo"' "$W" >/dev/null || fail "sudo path is not pinned"
grep -F 'exec "$SUDO" -- "$ROOT_INSTALLER"' "$W" >/dev/null   || fail "MCP wrapper fixed sudo invocation missing"

grep -F 'REPO="/home/ryohryp/personal-orbit"' "$R" >/dev/null || fail "Personal Orbit repo is not pinned"
grep -F 'SOURCE_PATH="ops/bootstrap-note-publication-relay-ops"' "$R" >/dev/null   || fail "Personal Orbit reviewed bootstrap source is not pinned"
grep -F 'EXPECTED_SOURCE_BLOB="9aae8b09b846119beea7fac756e2bc4fe67bb43f"' "$R" >/dev/null   || fail "approved relay bootstrap blob is not pinned"
grep -F 'EXPECTED_WRAPPER_BLOB="3ca45a109a65cd545c43a7070b059a4378b7b27d"' "$R" >/dev/null   || fail "approved relay wrapper blob is not pinned"
grep -F 'EXPECTED_HELPER_BLOB="b92d4cac36a431d19810486a20ec43dff422e9ab"' "$R" >/dev/null   || fail "approved relay helper blob is not pinned"
grep -F 'EXPECTED_WORKFLOW_BLOB="42ffaa7612d73dfc4768c8f8f4c26b6423870e0e"' "$R" >/dev/null   || fail "approved relay workflow blob is not pinned"
grep -F 'TARGET_BOOTSTRAP="/usr/local/sbin/bootstrap-note-publication-relay-ops"' "$R" >/dev/null   || fail "Personal Orbit bootstrap target is not pinned"
grep -F 'fetch --no-tags "$REMOTE" "refs/heads/main:$SOURCE_REF"' "$R" >/dev/null   || fail "current origin/main fetch is missing"
grep -F 'verify_blob "$SOURCE_PATH" "$EXPECTED_SOURCE_BLOB"' "$R" >/dev/null   || fail "relay bootstrap blob is not verified"
grep -F 'verify_blob "$WRAPPER_SOURCE_PATH" "$EXPECTED_WRAPPER_BLOB"' "$R" >/dev/null   || fail "relay wrapper blob is not verified"
grep -F 'verify_blob "$HELPER_SOURCE_PATH" "$EXPECTED_HELPER_BLOB"' "$R" >/dev/null   || fail "relay helper blob is not verified"
grep -F 'verify_blob "$WORKFLOW_SOURCE_PATH" "$EXPECTED_WORKFLOW_BLOB"' "$R" >/dev/null   || fail "relay workflow blob is not verified"
grep -F 'show "$source_sha:$SOURCE_PATH"' "$R" >/dev/null   || fail "reviewed bootstrap is not extracted from the verified main"
grep -F '"$TARGET_BOOTSTRAP" "$source_sha"' "$R" >/dev/null   || fail "reviewed bootstrap is not invoked with the verified SHA"
grep -F '/bin/rm -f -- "$SELF_SUDOERS"' "$R" >/dev/null   || fail "one-time sudoers cleanup missing"
grep -F '/bin/rm -f -- "$SELF_PATH"' "$R" >/dev/null   || fail "one-time root installer cleanup missing"
grep -F "export PATH='/usr/sbin:/usr/bin:/sbin:/bin'" "$R" >/dev/null   || fail "root bootstrap does not pin PATH"
grep -F 'target_installed=1' "$R" >/dev/null   || fail "temporary child bootstrap installation is not tracked"
grep -F '/bin/rm -f -- "$TARGET_BOOTSTRAP"' "$R" >/dev/null   || fail "failed child bootstrap cleanup is missing"
grep -F '[ "${SUDO_COMMAND:-}" = "$SELF_PATH" ]' "$R" >/dev/null   || fail "sudo command identity is not checked"
grep -F 'expected_sudo_rule="$sudo_user ALL=(root) NOPASSWD: $SELF_PATH"' "$R" >/dev/null   || fail "exact sudo rule is not constructed"
grep -F '[ "$actual_sudo_rule" = "$expected_sudo_rule" ]' "$R" >/dev/null   || fail "installed sudoers rule is not checked exactly"

if grep -E 'systemctl|NOTE_PUBLICATION_V3_RELAY_MODE|configure-note-publication-relay[[:space:]]+(off|poll)' "$R" >/dev/null   || grep -E '^[[:space:]]*(exec[[:space:]]+)?sudo[[:space:]]' "$R" >/dev/null; then
  fail "root bootstrap contains an unrelated execution/configuration surface"
fi

grep -F 'personal_orbit_note_relay_bootstrap:' "$C" >/dev/null || fail "MCP mapping missing"
grep -F 'NOPASSWD: /usr/local/sbin/bootstrap-personal-orbit-note-relay' "$S" >/dev/null   || fail "sudoers command not fixed"
if grep -E 'NOPASSWD:.*\*|/bin/(ba)?sh|NOPASSWD:[[:space:]]*ALL([[:space:]]|$)' "$S" >/dev/null; then
  fail "sudoers example too broad"
fi

printf '%s\n' "PASS: Personal Orbit note relay bootstrap static policy checks"
