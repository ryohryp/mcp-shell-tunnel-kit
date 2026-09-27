1	#!/bin/sh
     2	set -eu
     3	
     4	# Install a reviewed copy outside the MCP workspace and edit these values there.
     5	REPO="/home/ryohryp/personal-orbit"
     6	REMOTE="origin"
     7	BRANCH="main"
     8	ROOT_INSTALLER="/usr/local/sbin/install-personal-orbit-deploy-helpers"
     9	
    10	die() {
    11	  printf '%s\n' "personal-orbit-helper-install: $*" >&2
    12	  exit 1
    13	}
    14	
    15	[ "$#" -eq 0 ] || die "arguments are not accepted"
    16	[ -d "$REPO/.git" ] || die "configured Personal Orbit repository is not a Git worktree"
    17	[ -x "$ROOT_INSTALLER" ] || die "root installer is unavailable"
    18	
    19	cd "$REPO"
    20	branch=$(git symbolic-ref --quiet --short HEAD) || die "detached HEAD is not allowed"
    21	[ "$branch" = "$BRANCH" ] || die "Personal Orbit checkout is not on main"
    22	[ -z "$(git status --porcelain)" ] || die "Personal Orbit checkout is not clean"
    23	
    24	remote_url=$(git remote get-url "$REMOTE") || die "configured remote is unavailable"
    25	case "$remote_url" in
    26	  https://github.com/ryohryp/personal-orbit.git|git@github.com:ryohryp/personal-orbit.git) ;;
    27	  *) die "configured remote is not the Personal Orbit repository" ;;
    28	esac
    29	
    30	local_sha=$(git rev-parse HEAD)
    31	remote_sha=$(git ls-remote "$REMOTE" refs/heads/main | awk '{print $1}')
    32	[ -n "$remote_sha" ] || die "origin/main could not be resolved"
    33	[ "$local_sha" = "$remote_sha" ] || die "local main is not the current origin/main"
    34	
    35	# The sudoers rule must allow exactly this no-argument command.
    36	exec sudo -- "$ROOT_INSTALLER"