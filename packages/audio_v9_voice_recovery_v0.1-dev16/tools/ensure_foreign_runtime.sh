#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/runtime_common.sh"
FR="$ROOT/run/runtime/oorexx_foreign_runtime_v0.22.6"
[ -d "$FR" ] || { echo "FAIL Foreign Runtime not materialised: $FR" >&2; exit 2; }
REXX=$(av9_find_rexx) || { echo 'FAIL ooRexx executable not found' >&2; exit 2; }
av9_check_rexx "$REXX"
PREFIX=$(av9_oorexx_prefix "$REXX" || true)
LIBDIR=''; [ -n "$PREFIX" ] && LIBDIR=$(av9_oorexx_libdir "$PREFIX")
EVID="$ROOT/run/deployment"; mkdir -p "$EVID"
SO="$FR/build/libforeign_runtime.so"
[ -f "$SO" ] || { echo "FAIL Foreign Runtime binary absent: $SO" >&2; exit 2; }
initial_hash=$(sha256sum "$SO" | awk '{print $1}')
packaged_hash_authority=69e17621ccde0634d34754b945bb93bb355d64a47ca44bd71f63c706e878790f
probe(){
  LD_LIBRARY_PATH="$FR/build${LIBDIR:+:$LIBDIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  REXX_PATH="$FR/rexx${REXX_PATH:+:$REXX_PATH}" \
  "$REXX" "$ROOT/tools/probe_foreign_runtime.rex" >/dev/null 2>&1
}
required_glibc='unknown'
if command -v readelf >/dev/null 2>&1; then
  required_glibc=$(readelf --version-info "$SO" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | sort -V | tail -1 || true)
  [ -n "$required_glibc" ] || required_glibc='none'
fi
if [ "${AV9_FORCE_FOREIGN_REBUILD:-0}" != 1 ] && probe; then
  prior_rebuilt=false
  if [ -f "$EVID/foreign-runtime.tsv" ]; then prior_rebuilt=$(awk -F '\t' '$1=="ever_rebuilt" {print $2}' "$EVID/foreign-runtime.tsv"); fi
  if [ "$prior_rebuilt" = true ]; then action='reuse-rebuilt'; rebuilt='true'; else action='reuse'; rebuilt='false'; fi
else
  action='rebuild'; rebuilt='true'
  [ -n "$PREFIX" ] && [ -f "$PREFIX/include/oorexxapi.h" ] || { echo 'FAIL Foreign Runtime rebuild requires ooRexx headers (set OOREXX_PREFIX)' >&2; exit 3; }
  CXX=${CXX:-g++}; command -v "$CXX" >/dev/null 2>&1 || { echo "FAIL Foreign Runtime rebuild requires $CXX" >&2; exit 3; }
  tmp="$FR/build/libforeign_runtime.so.new.$$"
  "$CXX" -std=c++17 -O0 -fPIC -Wall -Wextra -I"$PREFIX/include" -shared -o "$tmp" "$FR/src/foreign_runtime.cpp" -ldl
  mv "$tmp" "$SO"
  probe || { echo 'FAIL rebuilt Foreign Runtime does not load through ooRexx' >&2; exit 4; }
fi
selected_hash=$(sha256sum "$SO" | awk '{print $1}')
compiler=$(${CXX:-g++} --version 2>/dev/null | sed -n '1p' || printf 'not-used')
{
 printf 'schema\taudio.v9.deployment.native/1\n'
 printf 'component\tforeign-runtime\n'
 printf 'policy\treuse-if-loadable-else-rebuild\n'
 printf 'action\t%s\n' "$action"
 printf 'rebuilt\t%s\n' "$rebuilt"
 printf 'packaged_sha256_authority\t%s\n' "$packaged_hash_authority"
 printf 'initial_selected_sha256\t%s\n' "$initial_hash"
 printf 'ever_rebuilt\t%s\n' "$rebuilt"
 printf 'selected_sha256\t%s\n' "$selected_hash"
 printf 'host_libc\t%s\n' "$(av9_glibc)"
 printf 'initial_required_glibc\t%s\n' "$required_glibc"
 printf 'compiler\t%s\n' "$compiler"
 printf 'oorexx\t%s\n' "$($REXX -v 2>&1 | sed -n '1p')"
} > "$EVID/foreign-runtime.tsv"
echo "READY foreign-runtime action=$action sha256=$selected_hash"
