#!/bin/sh
set -eu

REPO="/home/ryohryp/personal-orbit"
REPO_USER="ryohryp"
REPO_HOME="/home/ryohryp"
LIBEXEC_DIR="/usr/local/libexec/personal-orbit"
SBIN_DIR="/usr/local/sbin"
TUNNEL_BOOTSTRAP_PATH="$SBIN_DIR/bootstrap-gce-tunnel-ops-delegation"
RUNTIME_BOOTSTRAP_PATH="$SBIN_DIR/bootstrap-gce-runtime-artifact"
EXPECTED_ORIGIN="git@github.com:ryohryp/personal-orbit.git"
MAIN_REF="refs/remotes/origin/main"
SOURCE_SHA=""
TUNNEL_BOOTSTRAP_STAGED=0
RUNTIME_BOOTSTRAP_STAGED=0
TEMP_DIR=""

die() {
  printf '%s\n' "install-personal-orbit-deploy-helpers-root: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ "$(id -u)" -eq 0 ] || die "must run as root"
[ ! -L "$REPO" ] && [ -d "$REPO/.git" ] && [ ! -L "$REPO/.git" ] \
  || die "configured Personal Orbit repository is not a real Git worktree"

repo_git() {
  /usr/sbin/runuser --user "$REPO_USER" -- \
    /usr/bin/env -i \
      HOME="$REPO_HOME" \
      USER="$REPO_USER" \
      LOGNAME="$REPO_USER" \
      PATH="/usr/bin:/bin" \
      /usr/bin/git -C "$REPO" "$@"
}

checkout_branch=$(repo_git symbolic-ref --quiet --short HEAD) || checkout_branch=""
[ -z "$checkout_branch" ] || [ "$checkout_branch" = "main" ] \
  || die "checkout is on an unexpected branch"
[ -z "$(repo_git status --porcelain)" ] || die "checkout is not clean"

remote_url=$(repo_git remote get-url origin) || die "origin is unavailable"
[ "$remote_url" = "$EXPECTED_ORIGIN" ] || die "origin is not the expected Personal Orbit repository"

checkout_sha=$(repo_git rev-parse --verify HEAD) || die "checkout HEAD is unavailable"
repo_git fetch --no-tags origin refs/heads/main:refs/remotes/origin/main \
  || die "origin/main fetch failed"
SOURCE_SHA=$(repo_git rev-parse --verify "$MAIN_REF") || die "origin/main is unavailable"
case "$SOURCE_SHA" in
  *[!0-9a-f]*|'') die "origin/main SHA is invalid" ;;
esac
[ "${#SOURCE_SHA}" -eq 40 ] || die "origin/main SHA is invalid"
repo_git merge-base --is-ancestor "$checkout_sha" "$SOURCE_SHA" \
  || die "checkout HEAD is not an ancestor of origin/main"
remote_listing=$(repo_git ls-remote origin refs/heads/main) || die "origin/main could not be rechecked"
remote_sha=$(printf '%s\n' "$remote_listing" | awk '$2 == "refs/heads/main" {print $1}')
[ "$remote_sha" = "$SOURCE_SHA" ] || die "origin/main moved during helper installation"
[ "$(repo_git rev-parse --verify HEAD)" = "$checkout_sha" ] \
  || die "application checkout HEAD changed during source fetch"
[ -z "$(repo_git status --porcelain)" ] || die "application worktree changed during source fetch"

TEMP_DIR=$(mktemp -d) || die "could not create a temporary source directory"
cleanup() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ] && [ "$TUNNEL_BOOTSTRAP_STAGED" -eq 1 ]; then
    rm -f -- "$TUNNEL_BOOTSTRAP_PATH" || printf '%s\n' "install-personal-orbit-deploy-helpers-root: could not remove temporary Tunnel bootstrap" >&2
  fi
  if [ "$status" -ne 0 ] && [ "$RUNTIME_BOOTSTRAP_STAGED" -eq 1 ]; then
    rm -f -- "$RUNTIME_BOOTSTRAP_PATH" || printf '%s\n' "install-personal-orbit-deploy-helpers-root: could not remove temporary runtime bootstrap" >&2
  fi
  if [ -n "$TEMP_DIR" ]; then
    rm -rf -- "$TEMP_DIR" || {
      printf '%s\n' "install-personal-orbit-deploy-helpers-root: temporary source cleanup failed" >&2
      status=1
    }
  fi
  exit "$status"
}
trap cleanup EXIT

extract_source() {
  source_path=$1
  destination=$2
  source_mode=$(repo_git ls-tree "$SOURCE_SHA" -- "$source_path" | awk '{print $1}')
  case "$source_mode" in
    100644|100755) ;;
    *) die "reviewed source is not a regular Git file: $source_path" ;;
  esac
  repo_git show "$SOURCE_SHA:$source_path" > "$destination" \
    || die "could not extract reviewed source: $source_path"
  [ -s "$destination" ] || die "reviewed source is empty: $source_path"
}

assert_privileged_directory() {
  directory=$1
  [ -d "$directory" ] && [ ! -L "$directory" ] \
    || die "privileged path is not a real directory: $directory"
  metadata=$(stat --format='%U:%G:%a' "$directory") || die "could not inspect privileged directory: $directory"
  [ "${metadata%%:*}" = "root" ] || die "privileged directory is not root-owned: $directory"
  group_and_mode=${metadata#*:}
  [ "${group_and_mode%%:*}" = "root" ] || die "privileged directory group is invalid: $directory"
  directory_mode=${metadata##*:}
  case "$directory_mode" in
    *[!0-7]*|'') die "privileged directory mode is invalid: $directory" ;;
  esac
  group_digit=$(printf '%s' "$directory_mode" | awk '{print substr($0, length($0) - 1, 1)}')
  other_digit=$(printf '%s' "$directory_mode" | awk '{print substr($0, length($0), 1)}')
  case "$group_digit:$other_digit" in
    *2*|*3*|*6*|*7*) die "privileged directory is writable by group/others: $directory" ;;
  esac
}

assert_privileged_directory "$SBIN_DIR"
assert_privileged_directory /etc/sudoers.d

extract_source ops/bootstrap-gce-runtime-artifact "$TEMP_DIR/bootstrap-gce-runtime-artifact"
extract_source ops/bootstrap-gce-tunnel-ops-delegation "$TEMP_DIR/bootstrap-gce-tunnel-ops-delegation"

bash -n "$TEMP_DIR/bootstrap-gce-runtime-artifact"
bash -n "$TEMP_DIR/bootstrap-gce-tunnel-ops-delegation"

for bootstrap_path in "$RUNTIME_BOOTSTRAP_PATH" "$TUNNEL_BOOTSTRAP_PATH"; do
  if [ -e "$bootstrap_path" ] || [ -L "$bootstrap_path" ]; then
    [ -f "$bootstrap_path" ] && [ ! -L "$bootstrap_path" ] \
      || die "existing bootstrap target is not a regular file: $bootstrap_path"
    [ "$(stat --format='%U:%G:%a' "$bootstrap_path")" = "root:root:755" ] \
      || die "existing bootstrap ownership/mode is unexpected: $bootstrap_path"
  fi
done

if [ -e "$RUNTIME_BOOTSTRAP_PATH" ]; then
  cmp -s -- "$TEMP_DIR/bootstrap-gce-runtime-artifact" "$RUNTIME_BOOTSTRAP_PATH" \
    || die "refusing to replace an unexpected runtime bootstrap"
fi
if [ -e "$TUNNEL_BOOTSTRAP_PATH" ]; then
  cmp -s -- "$TEMP_DIR/bootstrap-gce-tunnel-ops-delegation" "$TUNNEL_BOOTSTRAP_PATH" \
    || die "refusing to replace an unexpected Tunnel bootstrap"
fi

RUNTIME_BOOTSTRAP_STAGED=1
install -o root -g root -m 0755 \
  "$TEMP_DIR/bootstrap-gce-runtime-artifact" "$RUNTIME_BOOTSTRAP_PATH"
"$RUNTIME_BOOTSTRAP_PATH" "$SOURCE_SHA"
[ ! -e "$RUNTIME_BOOTSTRAP_PATH" ] && [ ! -L "$RUNTIME_BOOTSTRAP_PATH" ] \
  || die "runtime bootstrap did not remove its temporary fixed path"
RUNTIME_BOOTSTRAP_STAGED=0

TUNNEL_BOOTSTRAP_STAGED=1
install -o root -g root -m 0755 \
  "$TEMP_DIR/bootstrap-gce-tunnel-ops-delegation" "$TUNNEL_BOOTSTRAP_PATH"
"$TUNNEL_BOOTSTRAP_PATH" "$SOURCE_SHA"
[ ! -e "$TUNNEL_BOOTSTRAP_PATH" ] && [ ! -L "$TUNNEL_BOOTSTRAP_PATH" ] \
  || die "Tunnel bootstrap did not remove its temporary fixed path"
TUNNEL_BOOTSTRAP_STAGED=0

printf '%s\n' "personal-orbit-helper-install: installed verified helpers from main $SOURCE_SHA"
