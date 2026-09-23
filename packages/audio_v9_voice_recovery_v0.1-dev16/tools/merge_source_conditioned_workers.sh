#!/bin/sh
set -eu
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "usage: $0 WORKERS_ROOT OUT_EVIDENCE.tsv [OUT_MANIFEST.sha256]" >&2
  exit 2
fi
ROOTS=$1; OUT=$2; MAN=${3:-"$OUT.sha256"}
mkdir -p "$(dirname "$OUT")"
first=1; workers=0; rows=0
: > "$OUT"
# Worker names are semantic order only for deterministic concatenation; solver itself is order independent.
for worker in ed209a ed209b ed209c ed209d ed209e ed209h ed209i; do
  wd="$ROOTS/$worker"
  f="$wd/evidence/source_path_evidence.tsv"
  [ -s "$wd/COMPLETE.tsv" ] || { echo "FAIL missing worker completion marker: $wd/COMPLETE.tsv" >&2; exit 2; }
  [ -s "$wd/EVIDENCE.sha256" ] || { echo "FAIL missing worker evidence hash: $wd/EVIDENCE.sha256" >&2; exit 2; }
  [ -s "$f" ] || { echo "FAIL missing worker source evidence: $f" >&2; exit 2; }
  grep -qx "worker[[:space:]]$worker" "$wd/COMPLETE.tsv" || { echo "FAIL wrong worker completion marker: $worker" >&2; exit 2; }
  (cd "$wd" && sha256sum --check EVIDENCE.sha256 >/dev/null) || { echo "FAIL worker evidence hash mismatch: $worker" >&2; exit 2; }
  if [ "$first" -eq 1 ]; then cat "$f" > "$OUT"; first=0; else tail -n +2 "$f" >> "$OUT"; fi
  workers=$((workers+1)); n=$(awk 'END{print NR-1}' "$f"); rows=$((rows+n))
done
sha256sum "$OUT" > "$MAN"
echo "PASS merged source-conditioned workers=$workers evidence_rows=$rows out=$OUT"
