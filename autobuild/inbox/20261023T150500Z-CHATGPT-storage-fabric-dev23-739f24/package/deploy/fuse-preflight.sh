#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0
check(){
  local label=$1; shift
  if "$@" >/dev/null 2>&1; then printf 'PASS %-24s\n' "$label"; else printf 'FAIL %-24s\n' "$label"; fail=1; fi
}
check 'Linux /dev/fuse' test -c /dev/fuse
check 'fusermount3' command -v fusermount3
check 'mountpoint' command -v mountpoint
check 'C compiler' command -v "${CC:-cc}"
check 'pkg-config' command -v pkg-config
if command -v pkg-config >/dev/null 2>&1; then
  check 'libfuse3 development' pkg-config --exists fuse3
  check 'libfuse3 >= 3.5' pkg-config --atleast-version=3.5 fuse3
fi
check 'ooRexx rexx' command -v rexx
if [[ -x "$ROOT/build/storage-fuse3" ]]; then
  if "$ROOT/native/probe-fuse3.sh" "$ROOT/build/storage-fuse3" >/dev/null 2>&1; then
    printf 'PASS %-24s\n' 'storage-fuse3 derivative'
  else
    printf 'FAIL %-24s\n' 'storage-fuse3 derivative'
    fail=1
  fi
else
  printf 'INFO %-24s %s\n' 'storage-fuse3 derivative' 'not yet built/sealed'
fi
if [[ -n "${REXX_PATH:-}" ]]; then printf 'PASS %-24s\n' 'REXX_PATH set'; else printf 'INFO %-24s %s\n' 'REXX_PATH set' 'required at mount runtime'; fi
exit "$fail"
