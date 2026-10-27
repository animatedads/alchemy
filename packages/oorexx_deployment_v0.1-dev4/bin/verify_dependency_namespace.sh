#!/bin/sh
set -eu
root=${1:-}
[ -n "$root" ] && [ -d "$root" ] || { echo 'usage: verify_dependency_namespace.sh DIR' >&2; exit 2; }
[ -f "$root/MANIFEST.sha256" ] || { echo 'FAIL namespace manifest absent' >&2; exit 4; }
(
  cd "$root"
  sha256sum -c MANIFEST.sha256 >/dev/null
)
[ -f "$root/evidence/dependency.lock.tsv" ] || { echo 'FAIL dependency lock evidence absent' >&2; exit 4; }
[ -f "$root/evidence/rexx-path.txt" ] || { echo 'FAIL REXX_PATH evidence absent' >&2; exit 4; }
while IFS= read -r p; do
  [ -d "$p" ] || { echo "FAIL REXX_PATH directory absent: $p" >&2; exit 4; }
done < "$root/evidence/rexx-path.txt"
echo "READY dependency-namespace verified=$root"
