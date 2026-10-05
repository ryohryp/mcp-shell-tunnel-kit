#!/bin/sh
set -eu

WRAPPER="scripts/bootstrap-personal-orbit-runtime-artifact.sh"
ROOT="scripts/bootstrap-personal-orbit-runtime-artifact-root.sh"
CONFIG="examples/security-development.yaml"
SUDOERS="examples/sudoers-personal-orbit-runtime-artifact-bootstrap"

fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

for script in "$WRAPPER" "$ROOT"; do
  sh -n "$script" || fail "shell syntax invalid: $script"
  grep -F '[ "$#" -eq 0 ]' "$script" >/dev/null || fail "arguments must be rejected: $script"
  if grep -E 'sh -c|bash -c|eval ' "$script" >/dev/null; then
    fail "shell escape present: $script"
  fi
done

grep -F 'ROOT_BOOTSTRAP="/usr/local/sbin/bootstrap-personal-orbit-runtime-artifact"' "$WRAPPER" >/dev/null   || fail "wrapper root bootstrap path is not pinned"
grep -F 'exec sudo -n -- "$ROOT_BOOTSTRAP"' "$WRAPPER" >/dev/null   || fail "wrapper does not invoke fixed root bootstrap non-interactively"

grep -F 'REPO="/home/ryohryp/personal-orbit"' "$ROOT" >/dev/null || fail "Personal Orbit repository is not pinned"
grep -F 'REPO_USER="ryohryp"' "$ROOT" >/dev/null || fail "repository owner is not pinned"
grep -F 'EXPECTED_ORIGIN="git@github.com:ryohryp/personal-orbit.git"' "$ROOT" >/dev/null || fail "exact Personal Orbit origin is not pinned"
grep -F 'MAIN_REF="refs/remotes/origin/main"' "$ROOT" >/dev/null || fail "origin/main ref is not pinned"
grep -F 'repo_git fetch --no-tags origin refs/heads/main:refs/remotes/origin/main' "$ROOT" >/dev/null   || fail "root bootstrap does not fetch origin/main"
grep -F 'repo_git merge-base --is-ancestor "$checkout_sha" "$SOURCE_SHA"' "$ROOT" >/dev/null   || fail "checkout HEAD must belong to reviewed origin/main history"
grep -F 'repo_git ls-remote origin refs/heads/main' "$ROOT" >/dev/null   || fail "origin/main is not rechecked"
grep -F 'source_path="ops/bootstrap-gce-runtime-artifact"' "$ROOT" >/dev/null   || fail "runtime artifact bootstrap source is not pinned"
grep -F '"$RUNTIME_BOOTSTRAP_PATH" "$SOURCE_SHA"' "$ROOT" >/dev/null   || fail "SHA-bound runtime bootstrap is not executed"
grep -F 'runtime bootstrap did not remove its temporary fixed path' "$ROOT" >/dev/null   || fail "temporary runtime bootstrap cleanup is not checked"

if grep -E 'bootstrap-gce-tunnel|systemctl|journalctl|NOPASSWD: ALL|deploy-personal-orbit-note|configure-note-publication' "$ROOT" >/dev/null; then
  fail "runtime-only root bootstrap includes an operation outside the approved scope"
fi

grep -F 'personal_orbit_runtime_artifact_bootstrap:' "$CONFIG" >/dev/null || fail "MCP mapping missing"
grep -F 'NOPASSWD: /usr/local/sbin/bootstrap-personal-orbit-runtime-artifact ""' "$SUDOERS" >/dev/null   || fail "sudoers command must explicitly reject arguments"

sudoers_policy=$(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$SUDOERS")
[ "$sudoers_policy" = 'mcp-shell ALL=(root) NOPASSWD: /usr/local/sbin/bootstrap-personal-orbit-runtime-artifact ""' ]   || fail "sudoers example must grant only the fixed root bootstrap with no arguments"
if printf '%s\n' "$sudoers_policy" | grep -E '/bin/(ba)?sh|\*' >/dev/null; then
  fail "sudoers example is broader than the fixed root bootstrap"
fi

printf '%s\n' "PASS: Personal Orbit runtime artifact bootstrap static policy checks"
