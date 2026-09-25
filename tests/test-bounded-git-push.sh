#!/bin/sh
set -eu

SCRIPT="scripts/bounded-git-push.sh"

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

grep -F 'REPO="/opt/mcp-shell/workspace"' "$SCRIPT" >/dev/null || fail "repository must be pinned"
grep -F 'REMOTE="origin"' "$SCRIPT" >/dev/null || fail "remote must be pinned"
grep -F 'ALLOWED_BRANCHES="main"' "$SCRIPT" >/dev/null || fail "branch allowlist missing"
grep -F '[ "$#" -eq 0 ]' "$SCRIPT" >/dev/null || fail "caller arguments must be rejected"
grep -F 'git symbolic-ref --quiet --short HEAD' "$SCRIPT" >/dev/null || fail "detached HEAD check missing"
grep -F 'git remote get-url "$REMOTE"' "$SCRIPT" >/dev/null || fail "remote validation missing"
grep -F 'exec git push "$REMOTE" "HEAD:refs/heads/$branch"' "$SCRIPT" >/dev/null || fail "bounded push missing"

if grep -E -- '(^|[[:space:]])(--force|-f)([[:space:]]|$)' "$SCRIPT" >/dev/null; then
  fail "force push option present"
fi
if grep -E 'sh -c|bash -c|eval ' "$SCRIPT" >/dev/null; then
  fail "shell escape present"
fi

printf '%s\n' "PASS: bounded git push static policy checks"
