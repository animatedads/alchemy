#!/bin/sh
set -eu
root=${1:-}
[ -n "$root" ] && [ -d "$root" ] || { echo 'usage: verify_dependency_namespace.sh DIR' >&2; exit 2; }
[ -f "$root/MANIFEST.sha256" ] || { echo 'FAIL namespace manifest absent' >&2; exit 4; }
( cd "$root"; sha256sum -c MANIFEST.sha256 >/dev/null )
[ -f "$root/evidence/dependency.lock.tsv" ] || { echo 'FAIL dependency lock evidence absent' >&2; exit 4; }
# Relative path evidence is the portable authority after a sealed namespace is
# moved from construction storage to its final release root. Fall back to the
# dev4 absolute path list only for older namespaces.
if [ -f "$root/evidence/rexx-path.relative.txt" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in ''|/*|../*|*/../*|*/..|..) echo "FAIL unsafe relative REXX_PATH: $rel" >&2; exit 4;; esac
    [ -d "$root/$rel" ] || { echo "FAIL REXX_PATH directory absent: $root/$rel" >&2; exit 4; }
  done < "$root/evidence/rexx-path.relative.txt"
elif [ -f "$root/evidence/rexx-path.txt" ]; then
  while IFS= read -r p; do [ -d "$p" ] || { echo "FAIL REXX_PATH directory absent: $p" >&2; exit 4; }; done < "$root/evidence/rexx-path.txt"
else
  echo 'FAIL REXX_PATH evidence absent' >&2; exit 4
fi
echo "READY dependency-namespace verified=$root"
