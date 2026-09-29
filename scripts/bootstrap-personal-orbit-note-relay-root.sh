#!/bin/sh
set -eu

REPO="/home/ryohryp/personal-orbit"
DEPLOY_USER="ryohryp"
REMOTE="origin"
SOURCE_REF="refs/remotes/origin/main"
SOURCE_PATH="ops/bootstrap-note-publication-relay-ops"
TARGET_BOOTSTRAP="/usr/local/sbin/bootstrap-note-publication-relay-ops"
SELF_PATH="/usr/local/sbin/bootstrap-personal-orbit-note-relay"
SELF_SUDOERS="/etc/sudoers.d/mcp-shell-personal-orbit-note-relay-bootstrap"

die() {
  printf '%s\n' "bootstrap-personal-orbit-note-relay: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ "$(id -u)" -eq 0 ] || die "must run as root"
[ -d "$REPO/.git" ] || die "configured Personal Orbit repository is not a Git worktree"

for command in /bin/rm /usr/bin/bash /usr/bin/cmp /usr/bin/git /usr/bin/install /usr/bin/mktemp /usr/bin/readlink /usr/bin/stat /usr/sbin/runuser /usr/sbin/visudo; do
  [ -x "$command" ] || die "required executable is missing: $command"
done

[ "$(readlink -f -- "$0")" = "$SELF_PATH" ] || die "installer must run from its fixed root-owned path"
[ "$(stat --format='%U:%G:%a' "$SELF_PATH")" = "root:root:755" ] || die "installer ownership/mode is invalid"
[ -f "$SELF_SUDOERS" ] && [ ! -L "$SELF_SUDOERS" ] || die "bootstrap sudoers file is unavailable"
[ "$(stat --format='%U:%G:%a' "$SELF_SUDOERS")" = "root:root:440" ] || die "bootstrap sudoers ownership/mode is invalid"
visudo -cf "$SELF_SUDOERS" >/dev/null

origin_url=$(runuser --user "$DEPLOY_USER" -- git -C "$REPO" -c safe.directory="$REPO" remote get-url "$REMOTE")   || die "origin is unavailable"
case "$origin_url" in
  https://github.com/ryohryp/personal-orbit.git|git@github.com:ryohryp/personal-orbit.git) ;;
  *) die "origin is not the Personal Orbit repository" ;;
esac

runuser --user "$DEPLOY_USER" -- git -C "$REPO" -c safe.directory="$REPO"   fetch --no-tags "$REMOTE" "refs/heads/main:$SOURCE_REF"   || die "origin/main fetch failed"
source_sha=$(runuser --user "$DEPLOY_USER" -- git -C "$REPO" -c safe.directory="$REPO" rev-parse --verify "$SOURCE_REF")   || die "origin/main could not be resolved"
case "$source_sha" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
    [ "${#source_sha}" -eq 40 ] || die "origin/main SHA is invalid"
    ;;
  *) die "origin/main SHA is invalid" ;;
esac

[ ! -L "$TARGET_BOOTSTRAP" ] || die "target bootstrap must not be a symlink"
[ ! -e "$TARGET_BOOTSTRAP" ] || die "target bootstrap already exists; refusing to replace it"

tmpdir=$(mktemp -d)
candidate="$tmpdir/bootstrap-note-publication-relay-ops"
cleanup() {
  status=$?
  trap - EXIT
  rm -rf -- "$tmpdir"
  exit "$status"
}
trap cleanup EXIT

runuser --user "$DEPLOY_USER" -- git -C "$REPO" -c safe.directory="$REPO"   show "$source_sha:$SOURCE_PATH" > "$candidate"   || die "reviewed Personal Orbit relay bootstrap could not be extracted"
[ -s "$candidate" ] || die "reviewed Personal Orbit relay bootstrap is empty"
bash -n "$candidate" || die "reviewed Personal Orbit relay bootstrap has invalid shell syntax"

install -o root -g root -m 0755 "$candidate" "$TARGET_BOOTSTRAP"
[ "$(stat --format='%U:%G:%a' "$TARGET_BOOTSTRAP")" = "root:root:755" ]   || die "temporary Personal Orbit relay bootstrap ownership/mode is invalid"
cmp -s "$candidate" "$TARGET_BOOTSTRAP"   || die "temporary Personal Orbit relay bootstrap differs from reviewed source"

"$TARGET_BOOTSTRAP" "$source_sha"
[ ! -e "$TARGET_BOOTSTRAP" ] || die "Personal Orbit relay bootstrap did not self-remove after success"

rm -f -- "$SELF_SUDOERS"
rm -f -- "$SELF_PATH"
printf '%s\n' "personal-orbit-note-relay-bootstrap: installed bounded relay control from origin/main $source_sha"
