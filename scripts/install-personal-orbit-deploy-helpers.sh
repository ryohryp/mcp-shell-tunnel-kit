#!/bin/sh
set -eu

ROOT_INSTALLER="/usr/local/sbin/install-personal-orbit-deploy-helpers"

die() {
  printf '%s\n' "personal-orbit-helper-install: $*" >&2
  exit 1
}

[ "$#" -eq 0 ] || die "arguments are not accepted"
[ -x "$ROOT_INSTALLER" ] || die "root installer is unavailable"

# The MCP account may intentionally have no read permission on the application
# checkout. The root installer repeats all checkout checks through the pinned
# repository owner's identity before it reads or installs any source file.
exec sudo -n -- "$ROOT_INSTALLER"
