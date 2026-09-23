#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$here/../scripts/verify-mcp-config-remote.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
cat > "$tmp/security.yaml" <<'YAML'
security:
  enabled: true
  writes_enabled: false
  scripts:
    uptime: ["uptime"]
    linux_posture: ["/root/DO-NOT-RUN"]
YAML
run() {
    label=$1 expected=$2
    shift 2
    env MCP_SHELL_SEC_CONFIG_FILE="$tmp/security.yaml" sh "$script" "$@" > "$tmp/output"
    grep -Fq 'config inspection reason: CONFIG_FILE_ACCESSIBLE' "$tmp/output" || { printf 'FAIL %s missing accessible reason\n' "$label" >&2; exit 1; }
    grep -Fq "$expected" "$tmp/output" || {
        printf 'FAIL %s\n' "$label" >&2
        cat "$tmp/output" >&2
        exit 1
    }
    if grep -Fq "$tmp" "$tmp/output"; then
        printf 'FAIL %s leaks a path\n' "$label" >&2
        exit 1
    fi
    printf 'PASS %s\n' "$label"
}
run declared 'linux_posture declared in inherited config: YES'
sed -i '/linux_posture:/d' "$tmp/security.yaml"
run absent 'linux_posture declared in inherited config: NO'
cat > "$tmp/security.yaml" <<'YAML'
security:
  scripts:
    linux_posture: ["/root/DO-NOT-RUN"]
YAML
run restored 'linux_posture declared in inherited config: YES'
ln -s "$tmp/security.yaml" "$tmp/link"
MCP_SHELL_SEC_CONFIG_FILE="$tmp/link" sh "$script" > "$tmp/output"
grep -Fq 'inherited config path points to readable regular file: FAIL' "$tmp/output"
grep -Fq 'config inspection reason: CONFIG_FILE_SYMLINK' "$tmp/output"
printf 'PASS symlink\n'
MCP_SHELL_SEC_CONFIG_FILE="$tmp/missing" sh "$script" > "$tmp/output"
grep -Fq 'inherited config path points to readable regular file: FAIL' "$tmp/output"
grep -Fq 'config inspection reason: CONFIG_FILE_MISSING' "$tmp/output"
printf 'PASS missing\n'
env -u MCP_SHELL_SEC_CONFIG_FILE sh "$script" > "$tmp/output"
grep -Fq 'inherited config path points to readable regular file: UNVERIFIED' "$tmp/output"
grep -Fq 'config inspection reason: CONFIG_ENV_UNSET' "$tmp/output"
printf 'PASS missing environment\n'
MCP_SHELL_SEC_CONFIG_FILE=relative.yaml sh "$script" > "$tmp/output"
grep -Fq 'inherited config path points to readable regular file: UNVERIFIED' "$tmp/output"
grep -Fq 'config inspection reason: CONFIG_PATH_NOT_ABSOLUTE' "$tmp/output"
printf 'PASS relative path\n'
MCP_SHELL_SEC_CONFIG_FILE= sh "$script" > "$tmp/output"
grep -Fq 'config inspection reason: CONFIG_ENV_EMPTY' "$tmp/output"
grep -Fq 'inherited config path points to readable regular file: UNVERIFIED' "$tmp/output"
printf 'PASS empty environment\n'
mkdir "$tmp/directory"
MCP_SHELL_SEC_CONFIG_FILE="$tmp/directory" sh "$script" > "$tmp/output"
grep -Fq 'config inspection reason: CONFIG_NOT_REGULAR' "$tmp/output"
grep -Fq 'inherited config path points to readable regular file: FAIL' "$tmp/output"
printf 'PASS directory path\n'
MCP_SHELL_SEC_CONFIG_FILE="$tmp/missing" sh "$script" > "$tmp/output"
if grep -Fq "$tmp" "$tmp/output"; then
    printf '%s\n' 'FAIL diagnostic leaked a config path' >&2
    exit 1
fi
printf 'PASS bounded diagnostic output\n'
status=0
sh "$script" extra > "$tmp/output" 2>&1 || status=$?
[ "$status" -eq 2 ]
printf 'PASS rejects arguments\n'
