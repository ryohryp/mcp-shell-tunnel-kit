#!/bin/sh
set -eu
export PATH='/usr/sbin:/usr/bin:/sbin:/bin'

REPO="/home/ryohryp/personal-orbit"
DEPLOY_USER="ryohryp"
REMOTE="origin"
SOURCE_REF="refs/remotes/origin/main"
SOURCE_PATH="ops/bootstrap-note-publication-relay-ops"
WRAPPER_SOURCE_PATH="ops/configure-note-publication-relay"
HELPER_SOURCE_PATH="ops/configure-note-publication-relay-env.sh"
WORKFLOW_SOURCE_PATH=".github/workflows/configure-note-publication-relay.yml"
EXPECTED_SOURCE_BLOB="9aae8b09b846119beea7fac756e2bc4fe67bb43f"
EXPECTED_WRAPPER_BLOB="3ca45a109a65cd545c43a7070b059a4378b7b27d"
EXPECTED_HELPER_BLOB="b92d4cac36a431d19810486a20ec43dff422e9ab"
EXPECTED_WORKFLOW_BLOB="42ffaa7612d73dfc4768c8f8f4c26b6423870e0e"
TARGET_BOOTSTRAP="/usr/local/sbin/bootstrap-note-publication-relay-ops"
SELF_PATH="/usr/local/sbin/bootstrap-personal-orbit-note-relay"
SELF_SUDOERS="/etc/sudoers.d/mcp-shell-personal-orbit-note-relay-bootstrap"

die() {
  printf '%s\n' "bootstrap-personal-orbit-note-relay: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ "$(/usr/bin/id -u)" -eq 0 ] || die "must run as root"
[ -d "$REPO/.git" ] || die "configured Personal Orbit repository is not a Git worktree"

for command in /bin/rm /usr/bin/bash /usr/bin/cmp /usr/bin/git /usr/bin/grep /usr/bin/id /usr/bin/install /usr/bin/mktemp /usr/bin/readlink /usr/bin/stat /usr/sbin/runuser /usr/sbin/visudo; do
  [ -x "$command" ] || die "required executable is missing: $command"
done

[ "$(/usr/bin/readlink -f -- "$0")" = "$SELF_PATH" ] || die "installer must run from its fixed root-owned path"
[ "$(/usr/bin/stat --format='%U:%G:%a' "$SELF_PATH")" = "root:root:755" ] || die "installer ownership/mode is invalid"
[ -f "$SELF_SUDOERS" ] && [ ! -L "$SELF_SUDOERS" ] || die "bootstrap sudoers file is unavailable"
[ "$(/usr/bin/stat --format='%U:%G:%a' "$SELF_SUDOERS")" = "root:root:440" ] || die "bootstrap sudoers ownership/mode is invalid"
/usr/sbin/visudo -cf "$SELF_SUDOERS" >/dev/null

sudo_user="${SUDO_USER:-}"
[ -n "$sudo_user" ] || die "installer must be invoked through sudo"
case "$sudo_user" in
  root|*[!A-Za-z0-9_.-]*) die "sudo caller identity is invalid" ;;
esac
/usr/bin/id "$sudo_user" >/dev/null 2>&1 || die "sudo caller identity does not exist"
[ "$(/usr/bin/id -u "$sudo_user")" -ne 0 ] || die "sudo caller must be unprivileged"
[ "${SUDO_COMMAND:-}" = "$SELF_PATH" ] || die "sudo command does not match the fixed installer path"
expected_sudo_rule="$sudo_user ALL=(root) NOPASSWD: $SELF_PATH"
actual_sudo_rule=$(/usr/bin/grep -Ev '^[[:space:]]*(#|$)' "$SELF_SUDOERS" || true)
[ "$actual_sudo_rule" = "$expected_sudo_rule" ] || die "bootstrap sudoers rule is broader than the fixed installer command"

origin_url=$(/usr/sbin/runuser --user "$DEPLOY_USER" -- /usr/bin/git -C "$REPO" -c safe.directory="$REPO" remote get-url "$REMOTE")   || die "origin is unavailable"
case "$origin_url" in
  https://github.com/ryohryp/personal-orbit.git|git@github.com:ryohryp/personal-orbit.git) ;;
  *) die "origin is not the Personal Orbit repository" ;;
esac

/usr/sbin/runuser --user "$DEPLOY_USER" -- /usr/bin/git -C "$REPO" -c safe.directory="$REPO"   fetch --no-tags "$REMOTE" "refs/heads/main:$SOURCE_REF"   || die "origin/main fetch failed"
source_sha=$(/usr/sbin/runuser --user "$DEPLOY_USER" -- /usr/bin/git -C "$REPO" -c safe.directory="$REPO" rev-parse --verify "$SOURCE_REF")   || die "origin/main could not be resolved"
[ "${#source_sha}" -eq 40 ] || die "origin/main SHA is invalid"
case "$source_sha" in
  *[!0-9a-f]*) die "origin/main SHA is invalid" ;;
esac
verify_blob() {
  path="$1"
  expected="$2"
  actual=$(/usr/sbin/runuser --user "$DEPLOY_USER" -- /usr/bin/git -C "$REPO" -c safe.directory="$REPO"     rev-parse --verify "$source_sha:$path") || die "reviewed source path is unavailable: $path"
  [ "$actual" = "$expected" ] || die "reviewed source blob mismatch: $path"
}

verify_blob "$SOURCE_PATH" "$EXPECTED_SOURCE_BLOB"
verify_blob "$WRAPPER_SOURCE_PATH" "$EXPECTED_WRAPPER_BLOB"
verify_blob "$HELPER_SOURCE_PATH" "$EXPECTED_HELPER_BLOB"
verify_blob "$WORKFLOW_SOURCE_PATH" "$EXPECTED_WORKFLOW_BLOB"

[ ! -L "$TARGET_BOOTSTRAP" ] || die "target bootstrap must not be a symlink"
[ ! -e "$TARGET_BOOTSTRAP" ] || die "target bootstrap already exists; refusing to replace it"

tmpdir=$(/usr/bin/mktemp -d)
candidate="$tmpdir/bootstrap-note-publication-relay-ops"
target_installed=0
cleanup() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ] && [ "$target_installed" -eq 1 ] && [ -f "$TARGET_BOOTSTRAP" ] && [ ! -L "$TARGET_BOOTSTRAP" ]; then
    if [ "$(/usr/bin/stat --format='%U:%G:%a' "$TARGET_BOOTSTRAP")" = "root:root:755" ]       && /usr/bin/cmp -s "$candidate" "$TARGET_BOOTSTRAP"; then
      /bin/rm -f -- "$TARGET_BOOTSTRAP"
    fi
  fi
  /bin/rm -rf -- "$tmpdir"
  exit "$status"
}
trap cleanup EXIT

/usr/sbin/runuser --user "$DEPLOY_USER" -- /usr/bin/git -C "$REPO" -c safe.directory="$REPO"   show "$source_sha:$SOURCE_PATH" > "$candidate"   || die "reviewed Personal Orbit relay bootstrap could not be extracted"
[ -s "$candidate" ] || die "reviewed Personal Orbit relay bootstrap is empty"
/usr/bin/bash -n "$candidate" || die "reviewed Personal Orbit relay bootstrap has invalid shell syntax"

/usr/bin/install -o root -g root -m 0755 "$candidate" "$TARGET_BOOTSTRAP"
target_installed=1
[ "$(/usr/bin/stat --format='%U:%G:%a' "$TARGET_BOOTSTRAP")" = "root:root:755" ]   || die "temporary Personal Orbit relay bootstrap ownership/mode is invalid"
/usr/bin/cmp -s "$candidate" "$TARGET_BOOTSTRAP"   || die "temporary Personal Orbit relay bootstrap differs from reviewed source"

"$TARGET_BOOTSTRAP" "$source_sha"
[ ! -e "$TARGET_BOOTSTRAP" ] || die "Personal Orbit relay bootstrap did not self-remove after success"
target_installed=0

/bin/rm -f -- "$SELF_SUDOERS"
/bin/rm -f -- "$SELF_PATH"
printf '%s\n' "personal-orbit-note-relay-bootstrap: installed bounded relay control from origin/main $source_sha"
