#!/bin/sh
# Launch one ooRexx program under a previously materialised, content-verified
# Deployment dependency namespace. Ambient REXX_PATH is deliberately discarded.
set -eu
if [ "$#" -lt 2 ]; then
  echo "usage: $0 NAMESPACE PROGRAM [ARGS...]" >&2
  exit 2
fi
ns=$1; shift
program=$1; shift
[ -d "$ns" ] || { echo "FAIL dependency namespace absent: $ns" >&2; exit 4; }
[ -f "$ns/MANIFEST.sha256" ] || { echo "FAIL namespace manifest absent: $ns" >&2; exit 4; }
[ -f "$program" ] || { echo "FAIL ooRexx program absent: $program" >&2; exit 4; }
command -v sha256sum >/dev/null 2>&1 || { echo 'FAIL sha256sum unavailable' >&2; exit 4; }
REXX=${OOREXX_REXX:-/usr/bin/rexx}
[ -x "$REXX" ] || command -v "$REXX" >/dev/null 2>&1 || { echo "FAIL ooRexx launcher unavailable: $REXX" >&2; exit 4; }
(
  cd "$ns"
  sha256sum -c MANIFEST.sha256 >/dev/null
) || { echo "FAIL dependency namespace verification failed: $ns" >&2; exit 4; }
path=''
if [ -f "$ns/evidence/rexx-path.relative.txt" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in ''|/*|../*|*/../*|*/..|..) echo "FAIL unsafe relative REXX_PATH: $rel" >&2; exit 4;; esac
    p="$ns/$rel"
    [ -d "$p" ] || { echo "FAIL namespace path absent: $p" >&2; exit 4; }
    if [ -z "$path" ]; then path=$p; else path="$path:$p"; fi
  done < "$ns/evidence/rexx-path.relative.txt"
elif [ -f "$ns/evidence/rexx-path.txt" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -d "$p" ] || { echo "FAIL namespace path absent: $p" >&2; exit 4; }
    if [ -z "$path" ]; then path=$p; else path="$path:$p"; fi
  done < "$ns/evidence/rexx-path.txt"
else
  echo 'FAIL namespace REXX_PATH evidence absent' >&2; exit 4
fi
[ -n "$path" ] || { echo 'FAIL namespace has empty REXX_PATH' >&2; exit 4; }
REXX_PATH=$path
export REXX_PATH
exec "$REXX" "$program" "$@"
