#!/bin/sh
set -eu
S="scripts/bootstrap-personal-orbit-helper-mapping-root.sh"
fail(){ printf '%s\n' "FAIL: $*" >&2; exit 1; }
sh -n "$S" || fail "syntax"
grep -F '[ "$#" -eq 0 ]' "$S" >/dev/null || fail "arguments not rejected"
grep -F 'RUNTIME_ENV="/etc/tunnel-client/runtime.env"' "$S" >/dev/null || fail "runtime env not pinned"
grep -F 'CONFIG_KEY="MCP_SHELL_SEC_CONFIG_FILE"' "$S" >/dev/null || fail "config key not pinned"
grep -F 'personal_orbit_helper_install: ["/usr/local/libexec/personal-orbit/install-personal-orbit-deploy-helpers"]' "$S" >/dev/null || fail "mapping not exact"
grep -F 'exec sudo -n -- /usr/local/sbin/install-personal-orbit-deploy-helpers' "$S" >/dev/null || fail "wrapper command not fixed"
grep -F 'security config must be root-owned' "$S" >/dev/null || fail "config ownership unchecked"
grep -F 'security config must not be group/world writable' "$S" >/dev/null || fail "config mode unchecked"
grep -F 'cp -a -- "$config_path" "$backup_path"' "$S" >/dev/null || fail "backup missing"
grep -F 'mv -f -- "$config_tmp" "$config_path"' "$S" >/dev/null || fail "atomic replace missing"
grep -F 'cp -a -- "$backup_path" "$config_path"' "$S" >/dev/null || fail "rollback missing"
grep -F 'restart Tunnel separately' "$S" >/dev/null || fail "bootstrap must not restart Tunnel"
if grep -E 'systemctl|journalctl|NOPASSWD: ALL|bash -c|sh -c|eval ' "$S" >/dev/null; then fail "forbidden authority present"; fi
printf '%s\n' "PASS: helper live mapping bootstrap static policy checks"
