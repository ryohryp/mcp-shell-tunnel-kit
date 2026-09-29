#!/bin/sh
set -eu
RUNTIME_ENV="/etc/tunnel-client/runtime.env"
TARGET_WRAPPER="/usr/local/libexec/personal-orbit/install-personal-orbit-deploy-helpers"
ROOT_INSTALLER="/usr/local/sbin/install-personal-orbit-deploy-helpers"
MAPPING='    personal_orbit_helper_install: ["/usr/local/libexec/personal-orbit/install-personal-orbit-deploy-helpers"]'
BACKUP_SUFFIX=".before-personal-orbit-helper-mapping"
CONFIG_KEY="MCP_SHELL_SEC_CONFIG_FILE"
die() { printf '%s\n' "bootstrap-personal-orbit-helper-mapping-root: $*" >&2; exit 1; }
[ "$#" -eq 0 ] || die "arguments are not accepted"
[ "$(id -u)" -eq 0 ] || die "must run as root"
[ -f "$RUNTIME_ENV" ] && [ ! -L "$RUNTIME_ENV" ] || die "runtime env must be a regular file"
[ -x "$ROOT_INSTALLER" ] || die "fixed root installer is unavailable"
config_line=$(grep -E "^\${CONFIG_KEY}=" "$RUNTIME_ENV" || true)
[ -n "$config_line" ] || die "security config path is not declared"
[ "$(printf '%s\n' "$config_line" | wc -l)" -eq 1 ] || die "security config path must be declared exactly once"
config_path=${config_line#*=}
case "$config_path" in /*) ;; *) die "security config path must be absolute" ;; esac
[ -f "$config_path" ] && [ ! -L "$config_path" ] || die "security config must be a regular file"
config_dir=$(dirname -- "$config_path")
[ -d "$config_dir" ] && [ ! -L "$config_dir" ] || die "security config directory is invalid"
config_meta=$(stat -c '%u:%a' -- "$config_path")
config_owner=${config_meta%%:*}
config_mode=${config_meta#*:}
[ "$config_owner" = "0" ] || die "security config must be root-owned"
case "$config_mode" in *[!0-7]*|'') die "security config mode is invalid" ;; esac
[ $((0$config_mode & 0022)) -eq 0 ] || die "security config must not be group/world writable"
grep -Eq '^[[:space:]]*scripts:[[:space:]]*$' "$config_path" || die "security config has no scripts mapping"
if grep -Eq '^[[:space:]]*personal_orbit_helper_install:' "$config_path"; then
  grep -Fqx "$MAPPING" "$config_path" || die "existing helper mapping is unexpected"
  printf '%s\n' "bootstrap-personal-orbit-helper-mapping-root: mapping already present"
  exit 0
fi
wrapper_tmp=$(mktemp)
config_tmp=$(mktemp --tmpdir="$config_dir" .personal-orbit-helper-config.XXXXXX)
backup_path="$config_path$BACKUP_SUFFIX"
applied=0
cleanup() {
  status=$?
  trap - EXIT
  rm -f -- "$wrapper_tmp" "$config_tmp"
  if [ "$status" -ne 0 ] && [ "$applied" -eq 1 ] && [ -f "$backup_path" ]; then
    cp -a -- "$backup_path" "$config_path" || true
  fi
  exit "$status"
}
trap cleanup EXIT
cat >"$wrapper_tmp" <<'WRAPPER'
#!/bin/sh
set -eu
[ "$#" -eq 0 ] || { printf '%s\n' 'personal-orbit-helper-install: arguments are not accepted' >&2; exit 1; }
exec sudo -n -- /usr/local/sbin/install-personal-orbit-deploy-helpers
WRAPPER
sh -n "$wrapper_tmp"
target_dir=$(dirname -- "$TARGET_WRAPPER")
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] || die "target wrapper directory is invalid"
target_dir_meta=$(stat -c '%U:%G:%a' -- "$target_dir")
[ "${target_dir_meta%%:*}" = "root" ] || die "target wrapper directory must be root-owned"
target_rest=${target_dir_meta#*:}
[ "${target_rest%%:*}" = "root" ] || die "target wrapper directory group must be root"
target_mode=${target_dir_meta##*:}
[ $((0$target_mode & 0022)) -eq 0 ] || die "target wrapper directory must not be group/world writable"
if [ -e "$TARGET_WRAPPER" ] || [ -L "$TARGET_WRAPPER" ]; then
  [ -f "$TARGET_WRAPPER" ] && [ ! -L "$TARGET_WRAPPER" ] || die "existing target wrapper is invalid"
  [ "$(stat -c '%U:%G:%a' -- "$TARGET_WRAPPER")" = "root:root:755" ] || die "existing target wrapper metadata is unexpected"
  cmp -s -- "$wrapper_tmp" "$TARGET_WRAPPER" || die "refusing to replace unexpected target wrapper"
fi
awk -v mapping="$MAPPING" '
  BEGIN { inserted=0; in_scripts=0 }
  /^[[:space:]]*scripts:[[:space:]]*$/ { in_scripts=1; print; next }
  in_scripts && /^[^[:space:]#]/ && !inserted { print mapping; inserted=1; in_scripts=0 }
  { print }
  END {
    if (in_scripts && !inserted) print mapping
    if (!inserted && !in_scripts) exit 42
  }
' "$config_path" >"$config_tmp" || die "could not construct bounded security config update"
grep -Fqx "$MAPPING" "$config_tmp" || die "constructed config is missing exact helper mapping"
[ "$(grep -Ec '^[[:space:]]*personal_orbit_helper_install:' "$config_tmp")" -eq 1 ] || die "constructed config has duplicate helper mappings"
if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then die "backup path already exists; inspect it through the administration path"; fi
cp -a -- "$config_path" "$backup_path"
install -o root -g root -m 0755 "$wrapper_tmp" "$TARGET_WRAPPER"
applied=1
chown --reference="$config_path" "$config_tmp"
chmod --reference="$config_path" "$config_tmp"
mv -f -- "$config_tmp" "$config_path"
grep -Fqx "$MAPPING" "$config_path" || die "installed config failed exact mapping verification"
[ "$(stat -c '%u:%a' -- "$config_path")" = "$config_meta" ] || die "security config metadata changed unexpectedly"
[ "$(stat -c '%U:%G:%a' -- "$TARGET_WRAPPER")" = "root:root:755" ] || die "target wrapper metadata is invalid"
applied=0
printf '%s\n' "bootstrap-personal-orbit-helper-mapping-root: installed exact live mapping; restart Tunnel separately"
