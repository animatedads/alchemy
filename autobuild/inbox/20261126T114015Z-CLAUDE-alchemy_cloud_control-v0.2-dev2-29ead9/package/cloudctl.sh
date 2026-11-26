#!/bin/sh
# cloudctl.sh -- argv transport for cloudctl/cloudctl.rex (ooRexx Cloud Control).
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
# ooRexx receives one flattened argument string, so the exact shell argv is written here, one base64 line per
# argument, to a private temporary file.  Everything else -- providers, rules, ledger, logging -- is in cloudctl/.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
umask 077
argfile=$(mktemp "${TMPDIR:-/tmp}/cloudctl-argv.XXXXXX") || exit 2
trap 'rm -f "$argfile"' EXIT
trap 'rm -f "$argfile"; echo "cloudctl: interrupted" >&2; exit 130' INT TERM HUP
for a in "$@"; do
  printf '%s' "$a" | base64 -w0 >> "$argfile"
  echo >> "$argfile"
done
CLOUDCTL_ARGFILE=$argfile CLOUDCTL_HOME="$here/cloudctl" CLOUDCTL_BASE=$here "${OOREXX_REXX:-rexx}" "$here/cloudctl/cloudctl.rex"
exit $?
