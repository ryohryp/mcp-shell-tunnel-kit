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
grep -F "[ -z \"\$checkout_branch\" ] || [ \"\$checkout_branch\" = \"main\" ]" "$ROOT" >/dev/null \
  || fail "only detached HEAD or main branch may be used"
grep -F "repo_git merge-base --is-ancestor \"\$checkout_sha\" \"\$SOURCE_SHA\"" "$ROOT" >/dev/null \
  || fail "checkout HEAD must belong to reviewed origin/main history"
grep -F 'ops/bootstrap-gce-runtime-artifact' "$ROOT" >/dev/null || fail "protected runtime bootstrap source is not pinned"
grep -F '"$RUNTIME_BOOTSTRAP_PATH" "$SOURCE_SHA"' "$ROOT" >/dev/null || fail "root installer does not execute the SHA-bound runtime bootstrap"
grep -F 'runtime bootstrap did not remove its temporary fixed path' "$ROOT" >/dev/null || fail "temporary runtime bootstrap cleanup is not checked"
if grep -F 'ops/verify-runtime-artifact.mjs' "$ROOT" >/dev/null; then
  fail "legacy runtime verifier must not be installed directly"
fi
if grep -F 'ops/deploy-personal-orbit"' "$ROOT" >/dev/null; then
  fail "legacy deploy wrapper must not be installed directly"
fi
grep -F 'EXPECTED_ORIGIN="git@github.com:ryohryp/personal-orbit.git"' "$ROOT" >/dev/null || fail "exact Personal Orbit origin is not pinned"
grep -F 'repo_git fetch --no-tags origin refs/heads/main:refs/remotes/origin/main' "$ROOT" >/dev/null || fail "root installer does not fetch origin/main without checking out"
grep -F 'MAIN_REF="refs/remotes/origin/main"' "$ROOT" >/dev/null || fail "origin/main ref is not pinned"
grep -F 'repo_git ls-remote origin refs/heads/main' "$ROOT" >/dev/null || fail "root installer does not recheck origin/main"
grep -F "[ -d \"\$directory\" ] && [ ! -L \"\$directory\" ]" "$ROOT" >/dev/null || fail "privileged directories are not rejected when symlinks"
grep -F 'assert_privileged_directory /etc/sudoers.d' "$ROOT" >/dev/null || fail "sudoers directory trust is not checked"
grep -F 'ops/bootstrap-gce-tunnel-ops-delegation' "$ROOT" >/dev/null || fail "Tunnel bootstrap source is not pinned"
grep -F "\"\$TUNNEL_BOOTSTRAP_PATH\" \"\$SOURCE_SHA\"" "$ROOT" >/dev/null || fail "root installer does not execute the fixed SHA-bound bootstrap"
grep -F 'Tunnel bootstrap did not remove its temporary fixed path' "$ROOT" >/dev/null || fail "temporary Tunnel bootstrap cleanup is not checked"
if grep -E 'git checkout|systemctl|journalctl|NOPASSWD: ALL' "$ROOT" >/dev/null; then
  fail "root installer includes an operation outside the fixed helper install"
fi
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
