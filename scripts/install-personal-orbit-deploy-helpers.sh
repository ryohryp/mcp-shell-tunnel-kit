#!/bin/sh
set -eu

# Install a reviewed copy outside the MCP workspace and edit these values there.
REPO="/home/ryohryp/personal-orbit"
REMOTE="origin"
BRANCH="main"
ROOT_INSTALLER="/usr/local/sbin/install-personal-orbit-deploy-helpers"

die() {
  printf '%s\n' "personal-orbit-helper-install: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ -d "$REPO/.git" ] || die "configured Personal Orbit repository is not a Git worktree"
[ -x "$ROOT_INSTALLER" ] || die "root installer is unavailable"

cd "$REPO"
branch=$(git symbolic-ref --quiet --short HEAD) || die "detached HEAD is not allowed"
[ "$branch" = "$BRANCH" ] || die "Personal Orbit checkout is not on main"
[ -z "$(git status --porcelain)" ] || die "Personal Orbit checkout is not clean"

remote_url=$(git remote get-url "$REMOTE") || die "configured remote is unavailable"
case "$remote_url" in
  https://github.com/ryohryp/personal-orbit.git|git@github.com:ryohryp/personal-orbit.git) ;;
  *) die "configured remote is not the Personal Orbit repository" ;;
esac

local_sha=$(git rev-parse HEAD)
remote_sha=$(git ls-remote "$REMOTE" refs/heads/main | awk '{print $1}')
[ -n "$remote_sha" ] || die "origin/main could not be resolved"
[ "$local_sha" = "$remote_sha" ] || die "local main is not the current origin/main"

# The sudoers rule must allow exactly this no-argument command.
exec sudo -- "$ROOT_INSTALLER"
