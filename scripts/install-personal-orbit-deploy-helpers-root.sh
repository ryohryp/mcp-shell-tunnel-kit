1	#!/bin/sh
     2	set -eu
     3	
     4	REPO="/home/ryohryp/personal-orbit"
     5	LIBEXEC_DIR="/usr/local/libexec/personal-orbit"
     6	SBIN_DIR="/usr/local/sbin"
     7	
     8	die() {
     9	  printf '%s\n' "install-personal-orbit-deploy-helpers-root: $*" >&2
    10	  exit 1
    11	}
    12	
    13	[ "$#" -eq 0 ] || die "arguments are not accepted"
    14	[ "$(id -u)" -eq 0 ] || die "must run as root"
    15	[ -d "$REPO/.git" ] || die "configured Personal Orbit repository is not a Git worktree"
    16	
    17	cd "$REPO"
    18	[ "$(git symbolic-ref --quiet --short HEAD)" = "main" ] || die "checkout is not on main"
    19	[ -z "$(git status --porcelain)" ] || die "checkout is not clean"
    20	
    21	remote_url=$(git remote get-url origin) || die "origin is unavailable"
    22	case "$remote_url" in
    23	  https://github.com/ryohryp/personal-orbit.git|git@github.com:ryohryp/personal-orbit.git) ;;
    24	  *) die "origin is not the Personal Orbit repository" ;;
    25	esac
    26	
    27	local_sha=$(git rev-parse HEAD)
    28	remote_sha=$(git ls-remote origin refs/heads/main | awk '{print $1}')
    29	[ -n "$remote_sha" ] || die "origin/main could not be resolved"
    30	[ "$local_sha" = "$remote_sha" ] || die "local main is not the current origin/main"
    31	
    32	for source in \
    33	  ops/deploy-gce.sh \
    34	  ops/verify-runtime-artifact.mjs \
    35	  ops/deploy-personal-orbit
    36	do
    37	  [ -f "$source" ] && [ ! -L "$source" ] || die "invalid source: $source"
    38	done
    39	
    40	install -d -o root -g root -m 0755 "$LIBEXEC_DIR"
    41	install -o root -g root -m 0755 ops/deploy-gce.sh "$LIBEXEC_DIR/deploy-gce.sh"
    42	install -o root -g root -m 0755 ops/verify-runtime-artifact.mjs "$LIBEXEC_DIR/verify-runtime-artifact.mjs"
    43	install -o root -g root -m 0755 ops/deploy-personal-orbit "$SBIN_DIR/deploy-personal-orbit"
    44	
    45	for target in \
    46	  "$LIBEXEC_DIR/deploy-gce.sh" \
    47	  "$LIBEXEC_DIR/verify-runtime-artifact.mjs" \
    48	  "$SBIN_DIR/deploy-personal-orbit"
    49	do
    50	  [ "$(stat --format='%U:%G:%a' "$target")" = "root:root:755" ] || die "installed ownership/mode mismatch: $target"
    51	done
    52	
    53	node --check "$LIBEXEC_DIR/verify-runtime-artifact.mjs"
    54	bash -n "$SBIN_DIR/deploy-personal-orbit"
    55	bash -n "$LIBEXEC_DIR/deploy-gce.sh"
    56	
    57	printf '%s\n' "personal-orbit-helper-install: installed verified helpers from main $local_sha"