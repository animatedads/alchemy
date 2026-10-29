#!/bin/sh
set -eu
if [ "$#" -ne 3 ]; then echo "usage: $0 RUNTIME.tar.gz SHA256 TARGET_ROOT" >&2; exit 2; fi
archive=$1; expected=$2; root=$3
[ -f "$archive" ] || { echo "FAIL runtime archive absent: $archive" >&2; exit 2; }
got=$(sha256sum "$archive" | awk '{print $1}')
[ "$got" = "$expected" ] || { echo "FAIL runtime sha256 expected=$expected got=$got" >&2; exit 3; }
mkdir -p "$root"
marker="$root/.runtime-archive-sha256"
if [ ! -f "$marker" ] || [ "$(cat "$marker" 2>/dev/null || true)" != "$expected" ]; then
  tmp="$root.tmp.$$"; rm -rf "$tmp"; mkdir -p "$tmp"
  tar -xzf "$archive" -C "$tmp"
  [ -x "$tmp/bin/rexx" ] || { echo 'FAIL private runtime archive lacks bin/rexx' >&2; exit 4; }
  rm -rf "$root"; mv "$tmp" "$root"
  printf '%s\n' "$expected" > "$marker"
fi
rexx="$root/bin/rexx"
lib="$root/lib"; [ -d "$root/lib64" ] && lib="$root/lib64"
ver=$(LD_LIBRARY_PATH="$lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$rexx" -v 2>&1 | sed -n '1p')
case "$ver" in
  *"Open Object Rexx Version 5.3.0 r13196 - Internal Test Version"*) ;;
  *) echo "FAIL staged runtime mismatch: $ver" >&2; exit 5;;
esac
printf 'READY runtime=%s version=%s\n' "$rexx" "$ver"
