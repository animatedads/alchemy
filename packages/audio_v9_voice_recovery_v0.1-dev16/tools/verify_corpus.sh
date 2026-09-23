#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BASE=${1:-"$HOME/fcpaphos_originals/20231009_20231010"}
FC="$BASE/camera_fc"
FD="$BASE/camera_fd"
AUTH="$ROOT/campaign/FCPAPHOS_ORIGINALS_SHA256SUMS"
AUTH_SHA=a168f7d82f603f8d1671a7debf5a3aaae4a71a9c33f10cf2d22bff2e5453fae9

[ -d "$FC" ] || { echo "FAIL missing FC root: $FC" >&2; exit 2; }
[ -d "$FD" ] || { echo "FAIL missing FD root: $FD" >&2; exit 2; }
[ -f "$AUTH" ] || { echo "FAIL missing corpus SHA authority: $AUTH" >&2; exit 2; }

got_auth=$(sha256sum "$AUTH" | awk '{print $1}')
[ "$got_auth" = "$AUTH_SHA" ] || {
  echo "FAIL corpus authority checksum expected=$AUTH_SHA got=$got_auth" >&2
  exit 2
}

auth_lines=$(wc -l < "$AUTH" | tr -d ' ')
[ "$auth_lines" -eq 120 ] || {
  echo "FAIL corpus authority entry count expected=120 got=$auth_lines" >&2
  exit 2
}

TMP=${TMPDIR:-/tmp}/av9_voice_verify_$$
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP"

check_feed() {
  feed=$1
  dir=$2
  list=$3
  prefix=$4
  sort "$list" > "$TMP/${feed}.expected"
  find "$dir" -maxdepth 1 -type f -name '*_original.ogg' -printf '%f\n' | sort > "$TMP/${feed}.actual"
  if ! cmp -s "$TMP/${feed}.expected" "$TMP/${feed}.actual"; then
    echo "FAIL $feed filename inventory mismatch" >&2
    diff -u "$TMP/${feed}.expected" "$TMP/${feed}.actual" >&2 || true
    exit 2
  fi

  sed -n "s#^[0-9a-fA-F][0-9a-fA-F]*  ${prefix}/##p" "$AUTH" | sort > "$TMP/${feed}.authority"
  if ! cmp -s "$TMP/${feed}.expected" "$TMP/${feed}.authority"; then
    echo "FAIL $feed checksum-authority filename mismatch" >&2
    diff -u "$TMP/${feed}.expected" "$TMP/${feed}.authority" >&2 || true
    exit 2
  fi
}

check_feed FC "$FC" "$ROOT/campaign/FC_FILES.txt" camera_fc
check_feed FD "$FD" "$ROOT/campaign/FD_FILES.txt" camera_fd

fc_count=$(wc -l < "$ROOT/campaign/FC_FILES.txt" | tr -d ' ')
fd_count=$(wc -l < "$ROOT/campaign/FD_FILES.txt" | tr -d ' ')
bytes=0
while IFS= read -r name; do
  n=$(stat -c %s "$FC/$name")
  bytes=$((bytes+n))
done < "$ROOT/campaign/FC_FILES.txt"
while IFS= read -r name; do
  n=$(stat -c %s "$FD/$name")
  bytes=$((bytes+n))
done < "$ROOT/campaign/FD_FILES.txt"

[ "$fc_count" -eq 95 ] || { echo "FAIL FC count $fc_count" >&2; exit 2; }
[ "$fd_count" -eq 25 ] || { echo "FAIL FD count $fd_count" >&2; exit 2; }
[ "$bytes" -eq 4292920762 ] || {
  echo "FAIL corpus bytes expected=4292920762 got=$bytes" >&2
  exit 2
}

# Canonical per-file SHA-256 authority. Paths in AUTH are relative to BASE.
if ! (cd "$BASE" && sha256sum --check --quiet "$AUTH"); then
  echo "FAIL corpus SHA-256 verification" >&2
  exit 2
fi

echo "PASS corpus FC=$fc_count FD=$fd_count total=$((fc_count+fd_count)) bytes=$bytes sha256_entries=$auth_lines authority=$AUTH_SHA"
