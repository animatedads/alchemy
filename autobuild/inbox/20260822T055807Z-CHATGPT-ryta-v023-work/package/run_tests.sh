#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-all}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ryta-v023-git-autobuild.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PAYLOAD="$WORK/virtual_ryta_hardworld_v0.23_work.zip"
cat "$HERE"/payload/virtual_ryta_hardworld_v0.23_work.zip.b64.* | base64 -d > "$PAYLOAD"
EXPECTED="$(awk '$2 == "virtual_ryta_hardworld_v0.23_work.zip" {print $1}' "$HERE/payload/SHA256")"
ACTUAL="$(sha256sum "$PAYLOAD" | awk '{print $1}')"
[[ "$ACTUAL" == "$EXPECTED" ]] || {
  echo "payload checksum mismatch" >&2
  echo "expected=$EXPECTED" >&2
  echo "actual=$ACTUAL" >&2
  exit 70
}

mkdir -p "$WORK/source_unpack"
unzip -q "$PAYLOAD" -d "$WORK/source_unpack"
SRC="$WORK/source_unpack/virtual_ryta_hardworld_v0.23_work"

case "$MODE" in
  payload)
    echo "SOURCE ZIP SHA256: $ACTUAL"
    ;;
  source-manifest)
    cd "$SRC"
    sha256sum -c MANIFEST.sha256
    ;;
  compile)
    command -v rexxc >/dev/null 2>&1 || { echo "rexxc not found" >&2; exit 127; }
    count=0
    while IFS= read -r -d '' f; do
      rexxc "$f" >/dev/null
      count=$((count + 1))
    done < <(find "$SRC" -type f -name '*.cls' -print0 | sort -z)
    echo "REXXC classes: $count PASS"
    ;;
  inherited)
    cd "$SRC/tests"
    exec ./run_all.sh
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    exit 64
    ;;
esac
