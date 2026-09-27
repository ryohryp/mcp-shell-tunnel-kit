1	#!/bin/sh
     2	set -eu
     3	
     4	WRAPPER="scripts/install-personal-orbit-deploy-helpers.sh"
     5	ROOT="scripts/install-personal-orbit-deploy-helpers-root.sh"
     6	CONFIG="examples/security-development.yaml"
     7	SUDOERS="examples/sudoers-personal-orbit-helper-install"
     8	
     9	fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }
    10	
    11	for script in "$WRAPPER" "$ROOT"; do
    12	  sh -n "$script" || fail "shell syntax invalid: $script"
    13	  grep -F '[ "$#" -eq 0 ]' "$script" >/dev/null || fail "arguments must be rejected: $script"
    14	  if grep -E 'sh -c|bash -c|eval ' "$script" >/dev/null; then
    15	    fail "shell escape present: $script"
    16	  fi
    17	done
    18	
    19	grep -F 'REPO="/home/ryohryp/personal-orbit"' "$WRAPPER" >/dev/null || fail "Personal Orbit repository is not pinned"
    20	grep -F 'BRANCH="main"' "$WRAPPER" >/dev/null || fail "main branch is not pinned"
    21	grep -F 'exec sudo -- "$ROOT_INSTALLER"' "$WRAPPER" >/dev/null || fail "wrapper does not invoke fixed root installer"
    22	grep -F 'ops/verify-runtime-artifact.mjs' "$ROOT" >/dev/null || fail "runtime verifier is not installed"
    23	grep -F 'ops/deploy-personal-orbit' "$ROOT" >/dev/null || fail "root deploy wrapper is not installed"
    24	grep -F 'git ls-remote origin refs/heads/main' "$ROOT" >/dev/null || fail "root installer does not verify current origin/main"
    25	grep -F 'git status --porcelain' "$ROOT" >/dev/null || fail "root installer does not reject dirty checkout"
    26	grep -F 'personal_orbit_helper_install:' "$CONFIG" >/dev/null || fail "MCP mapping missing"
    27	grep -F 'NOPASSWD: /usr/local/sbin/install-personal-orbit-deploy-helpers' "$SUDOERS" >/dev/null || fail "sudoers command is not fixed"
    28	
    29	if grep -E 'ALL[[:space:]]*=|/bin/(ba)?sh|\*' "$SUDOERS" >/dev/null; then
    30	  fail "sudoers example is broader than the fixed installer"
    31	fi
    32	
    33	printf '%s\n' "PASS: Personal Orbit helper installer static policy checks"