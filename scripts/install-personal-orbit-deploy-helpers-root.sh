#!/bin/sh
set -eu

REPO="/home/ryohryp/personal-orbit"
LIBEXEC_DIR="/usr/local/libexec/personal-orbit"
SBIN_DIR="/usr/local/sbin"

die() {
  printf '%s\n' "install-personal-orbit-deploy-helpers-root: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ "$(id -u)" -eq 0 ] || die "must run as root"
[ -d "$REPO/.git" ] || die "configured Personal Orbit repository is not a Git worktree"

cd "$REPO"
[ "$(git symbolic-ref --quiet --short HEAD)" = "main" ] || die "checkout is not on main"
[ -z "$(git status --porcelain)" ] || die "checkout is not clean"

remote_url=$(git remote get-url origin) || die "origin is unavailable"
case "$remote_url" in
  https://github.com/ryohryp/personal-orbit.git|git@github.com:ryohryp/personal-orbit.git) ;;
  *) die "origin is not the Personal Orbit repository" ;;
esac

local_sha=$(git rev-parse HEAD)
remote_sha=$(git ls-remote origin refs/heads/main | awk '{print $1}')
[ -n "$remote_sha" ] || die "origin/main could not be resolved"
[ "$local_sha" = "$remote_sha" ] || die "local main is not the current origin/main"

for source in \
  ops/deploy-gce.sh \
  ops/verify-runtime-artifact.mjs \
  ops/deploy-personal-orbit
do
  [ -f "$source" ] && [ ! -L "$source" ] || die "invalid source: $source"
done

install -d -o root -g root -m 0755 "$LIBEXEC_DIR"
install -o root -g root -m 0755 ops/deploy-gce.sh "$LIBEXEC_DIR/deploy-gce.sh"
install -o root -g root -m 0755 ops/verify-runtime-artifact.mjs "$LIBEXEC_DIR/verify-runtime-artifact.mjs"
install -o root -g root -m 0755 ops/deploy-personal-orbit "$SBIN_DIR/deploy-personal-orbit"

for target in \
  "$LIBEXEC_DIR/deploy-gce.sh" \
  "$LIBEXEC_DIR/verify-runtime-artifact.mjs" \
  "$SBIN_DIR/deploy-personal-orbit"
do
  [ "$(stat --format='%U:%G:%a' "$target")" = "root:root:755" ] || die "installed ownership/mode mismatch: $target"
done

node --check "$LIBEXEC_DIR/verify-runtime-artifact.mjs"
bash -n "$SBIN_DIR/deploy-personal-orbit"
bash -n "$LIBEXEC_DIR/deploy-gce.sh"

printf '%s\n' "personal-orbit-helper-install: installed verified helpers from main $local_sha"
