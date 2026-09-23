#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/runtime_common.sh"
FR="$ROOT/run/runtime/oorexx_foreign_runtime_v0.22.6"
REXX=$(av9_find_rexx) || { echo 'FAIL ooRexx executable not found' >&2; exit 2; }
av9_check_rexx "$REXX"
PREFIX=$(av9_oorexx_prefix "$REXX" || true); LIBDIR=''; [ -n "$PREFIX" ] && LIBDIR=$(av9_oorexx_libdir "$PREFIX")
N="$ROOT/run/native"; EVID="$ROOT/run/deployment"; mkdir -p "$N" "$EVID"
cp "$ROOT/native/av9_spatial.bridge.json" "$N/av9_spatial.bridge.json"
[ -f "$N/libav9_spatial_provider.so" ] || cp "$ROOT/native/libav9_spatial_provider.so" "$N/libav9_spatial_provider.so"
SO="$N/libav9_spatial_provider.so"; bridge="$N/av9_spatial.bridge.json"
initial_hash=$(sha256sum "$SO" | awk '{print $1}')
probe(){
  (cd "$N" && LD_LIBRARY_PATH="$FR/build:$N${LIBDIR:+:$LIBDIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    REXX_PATH="$FR/rexx${REXX_PATH:+:$REXX_PATH}" "$REXX" "$ROOT/tools/probe_spatial_library.rex" "$bridge" >/dev/null 2>&1)
}
if [ "${AV9_FORCE_SPATIAL_REBUILD:-0}" != 1 ] && probe; then prior_rebuilt=false; if [ -f "$EVID/spatial-provider.tsv" ]; then prior_rebuilt=$(awk -F '\t' '$1=="ever_rebuilt" {print $2}' "$EVID/spatial-provider.tsv"); fi; if [ "$prior_rebuilt" = true ]; then action='reuse-rebuilt'; rebuilt='true'; else action='reuse'; rebuilt='false'; fi
else
  action='rebuild'; rebuilt='true'; CC=${CC:-gcc}; command -v "$CC" >/dev/null 2>&1 || { echo "FAIL spatial provider rebuild requires $CC" >&2; exit 3; }
  "$CC" -std=c11 -O3 -fPIC -Wall -Wextra -Werror -shared -o "$SO.new" "$ROOT/native/av9_spatial_provider.c" -lm
  mv "$SO.new" "$SO"
  probe || { echo 'FAIL rebuilt spatial provider does not load through Foreign Runtime' >&2; exit 4; }
fi
selected_hash=$(sha256sum "$SO" | awk '{print $1}')
{
 printf 'schema\taudio.v9.deployment.native/1\ncomponent\tspatial-provider\npolicy\treuse-if-loadable-else-rebuild\n'
 printf 'action\t%s\nrebuilt\t%s\never_rebuilt\t%s\ninitial_sha256\t%s\nselected_sha256\t%s\n' "$action" "$rebuilt" "$rebuilt" "$initial_hash" "$selected_hash"
 printf 'host_libc\t%s\n' "$(av9_glibc)"
} > "$EVID/spatial-provider.tsv"
echo "READY spatial-provider action=$action sha256=$selected_hash"
