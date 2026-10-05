#!/bin/sh
set -eu

ROOT_BOOTSTRAP="/usr/local/sbin/bootstrap-personal-orbit-runtime-artifact"

die() {
  printf '%s\n' "personal-orbit-runtime-artifact-bootstrap: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ -x "$ROOT_BOOTSTRAP" ] || die "root bootstrap is unavailable"

exec sudo -n -- "$ROOT_BOOTSTRAP"
