#!/bin/sh
set -eu

WRAPPER="scripts/install-personal-orbit-deploy-helpers.sh"
ROOT="scripts/install-personal-orbit-deploy-helpers-root.sh"
CONFIG="examples/security-development.yaml"
SUDOERS="examples/sudoers-personal-orbit-helper-install"

fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

for script in "$WRAPPER" "$ROOT"; do
  sh -n "$script" || fail "shell syntax invalid: $script"
  grep -F '[ "$#" -eq 0 ]' "$script" >/dev/null || fail "arguments must be rejected: $script"
  if grep -E 'sh -c|bash -c|eval ' "$script" >/dev/null; then
    fail "shell escape present: $script"
  fi
done

grep -F "exec sudo -n -- \"\$ROOT_INSTALLER\"" "$WRAPPER" >/dev/null || fail "wrapper does not invoke fixed root installer non-interactively"
if grep -E 'git |REPO=' "$WRAPPER" >/dev/null; then
  fail "MCP wrapper must not inspect or select a caller-inaccessible repository"
fi
grep -F 'REPO="/home/ryohryp/personal-orbit"' "$ROOT" >/dev/null || fail "Personal Orbit repository is not pinned"
grep -F 'REPO_USER="ryohryp"' "$ROOT" >/dev/null || fail "repository owner is not pinned"
grep -F "runuser --user \"\$REPO_USER\"" "$ROOT" >/dev/null || fail "root installer must validate through the repository owner's identity"
grep -F '= "main"' "$ROOT" >/dev/null || fail "main branch is not pinned"
grep -F 'ops/verify-runtime-artifact.mjs' "$ROOT" >/dev/null || fail "runtime verifier is not installed"
grep -F 'ops/deploy-personal-orbit' "$ROOT" >/dev/null || fail "root deploy wrapper is not installed"
grep -F 'repo_git ls-remote origin refs/heads/main' "$ROOT" >/dev/null || fail "root installer does not verify current origin/main"
grep -F 'repo_git status --porcelain' "$ROOT" >/dev/null || fail "root installer does not reject dirty checkout"
grep -F 'personal_orbit_helper_install:' "$CONFIG" >/dev/null || fail "MCP mapping missing"
grep -F 'NOPASSWD: /usr/local/sbin/install-personal-orbit-deploy-helpers ""' "$SUDOERS" >/dev/null || fail "sudoers command must explicitly reject arguments"

sudoers_policy=$(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$SUDOERS")
[ "$sudoers_policy" = "mcp-shell ALL=(root) NOPASSWD: /usr/local/sbin/install-personal-orbit-deploy-helpers \"\"" ] \
  || fail "sudoers example must grant only the fixed root installer with no arguments"
if printf '%s\n' "$sudoers_policy" | grep -E '/bin/(ba)?sh|\*' >/dev/null; then
  fail "sudoers example is broader than the fixed installer"
fi

printf '%s\n' "PASS: Personal Orbit helper installer static policy checks"
