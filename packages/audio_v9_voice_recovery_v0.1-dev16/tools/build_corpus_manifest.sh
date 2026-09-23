#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BASE=${1:-"$HOME/fcpaphos_originals/20231009_20231010"}
OUT=${2:-"$ROOT/run/FCPAPHOS_ORIGINALS_SHA256SUMS.local"}
AUTH="$ROOT/campaign/FCPAPHOS_ORIGINALS_SHA256SUMS"

# Full preflight includes canonical per-file SHA verification.
"$ROOT/tools/verify_corpus.sh" "$BASE" >/dev/null

mkdir -p "$(dirname "$OUT")"
: > "$OUT"
while IFS= read -r name; do
  p="$BASE/camera_fc/$name"
  printf '%s  camera_fc/%s\n' "$(sha256sum "$p" | awk '{print $1}')" "$name" >> "$OUT"
done < "$ROOT/campaign/FC_FILES.txt"
while IFS= read -r name; do
  p="$BASE/camera_fd/$name"
  printf '%s  camera_fd/%s\n' "$(sha256sum "$p" | awk '{print $1}')" "$name" >> "$OUT"
done < "$ROOT/campaign/FD_FILES.txt"

if ! cmp -s "$AUTH" "$OUT"; then
  echo "FAIL locally generated corpus manifest differs from canonical authority" >&2
  diff -u "$AUTH" "$OUT" >&2 || true
  exit 2
fi
sha256sum "$OUT"
