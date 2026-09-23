#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OOREXX_PREFIX=${OOREXX_PREFIX:-/usr/local}
mkdir -p "$ROOT/foreign"
STAMP="$ROOT/foreign/.native_build.sha256"
FR="$ROOT/foreign/libforeign_runtime.so"
DSP="$ROOT/foreign/libaudio_search_native.so"
FSYNC="$ROOT/foreign/audio_checkpoint_fsync"
HEADER="$OOREXX_PREFIX/include/oorexxapi.h"
[[ -f "$HEADER" ]] || { echo "FAIL: ooRexx development headers missing from $OOREXX_PREFIX/include" >&2; exit 4; }

fingerprint(){
  {
    printf 'foreign_runtime_sha256=%s\n' "$(sha256sum "$ROOT/native/foreign_runtime_v0.22.6.cpp" | awk '{print $1}')"
    printf 'audio_search_native_sha256=%s\n' "$(sha256sum "$ROOT/native/audio_search_native.c" | awk '{print $1}')"
    printf 'audio_checkpoint_fsync_sha256=%s\n' "$(sha256sum "$ROOT/native/audio_checkpoint_fsync.c" | awk '{print $1}')"
    printf 'oorexxapi_sha256=%s\n' "$(sha256sum "$HEADER" | awk '{print $1}')"
    printf 'build-contract=g++-c++17-O0-Wall-Wextra-Werror;gcc-c11-O3-Wall-Wextra-Werror-Wno-error=maybe-uninitialized;gcc-c11-O2-Wall-Wextra-Werror\n'
  } | sha256sum | awk '{print $1}'
}
expected=$(fingerprint)

runtime_valid(){
  [[ -s "$STAMP" && -x "$FR" && -x "$DSP" && -x "$FSYNC" ]] || return 1
  [[ "$(cat "$STAMP" 2>/dev/null)" == "$expected" ]] || return 1
  ldd -r "$FR" >/dev/null 2>&1 || return 1
  ldd -r "$DSP" >/dev/null 2>&1 || return 1
  "$FSYNC" "$STAMP" >/dev/null 2>&1 || return 1
  return 0
}

if runtime_valid; then
  printf 'PASS native runtime reused on %s (%s) fingerprint=%s\n' "$(hostname)" "$(uname -m)" "$expected"
  exit 0
fi

need_compiler=0
command -v gcc >/dev/null 2>&1 || need_compiler=1
command -v g++ >/dev/null 2>&1 || need_compiler=1
if [[ $need_compiler == 1 ]]; then
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian)
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential
      ;;
    ol|oracle|rhel|rocky|almalinux|amzn|fedora)
      sudo dnf install -y gcc gcc-c++ make
      ;;
    *)
      echo "FAIL: gcc/g++ missing and unsupported compiler bootstrap OS: ${ID:-unknown}" >&2
      exit 4
      ;;
  esac
fi

g++ -std=c++17 -O0 -fPIC -Wall -Wextra -Werror -I"$OOREXX_PREFIX/include" -shared \
  -o "$FR.new" "$ROOT/native/foreign_runtime_v0.22.6.cpp" -ldl
gcc -std=c11 -O3 -fPIC -Wall -Wextra -Werror -Wno-error=maybe-uninitialized -shared \
  -o "$DSP.new" "$ROOT/native/audio_search_native.c" -lm
gcc -std=c11 -O2 -Wall -Wextra -Werror \
  -o "$FSYNC.new" "$ROOT/native/audio_checkpoint_fsync.c"
mv "$FR.new" "$FR"
mv "$DSP.new" "$DSP"
mv "$FSYNC.new" "$FSYNC"
ldd -r "$FR" >/dev/null
ldd -r "$DSP" >/dev/null
# Commit the build identity last: a partially built runtime can never satisfy reuse.
printf '%s\n' "$expected" > "$STAMP.new"
mv "$STAMP.new" "$STAMP"
"$FSYNC" "$STAMP"
printf 'PASS native runtime built on %s (%s) fingerprint=%s\n' "$(hostname)" "$(uname -m)" "$expected"
