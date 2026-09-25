#!/bin/sh
set -eu

# Install a reviewed copy outside the MCP workspace and edit these values there.
REPO="/opt/mcp-shell/workspace"
REMOTE="origin"
ALLOWED_BRANCHES="main"

die() {
  printf '%s\n' "bounded-git-push: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ -d "$REPO/.git" ] || die "configured repository is not a Git worktree"

cd "$REPO"

branch=$(git symbolic-ref --quiet --short HEAD) || die "detached HEAD is not allowed"
case " $ALLOWED_BRANCHES " in
  *" $branch "*) ;;
  *) die "branch is not allowlisted" ;;
esac

remote_url=$(git remote get-url "$REMOTE") || die "configured remote is unavailable"
case "$remote_url" in
  https://github.com/*|git@github.com:*) ;;
  *) die "configured remote is not an approved GitHub URL" ;;
esac

# No caller-controlled remote, refspec, force flag, or extra Git arguments.
exec git push "$REMOTE" "HEAD:refs/heads/$branch"
