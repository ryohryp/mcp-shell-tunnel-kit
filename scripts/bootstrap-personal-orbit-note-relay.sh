#!/bin/sh
set -eu

ROOT_INSTALLER="/usr/local/sbin/bootstrap-personal-orbit-note-relay"
SUDO="/usr/bin/sudo"

die() {
  printf '%s\n' "personal-orbit-note-relay-bootstrap: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ -x "$ROOT_INSTALLER" ] || die "root installer is unavailable"
[ -x "$SUDO" ] || die "sudo is unavailable"

exec "$SUDO" -- "$ROOT_INSTALLER"
