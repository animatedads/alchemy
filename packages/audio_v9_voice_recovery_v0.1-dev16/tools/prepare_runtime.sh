#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
RUNTIME="$ROOT/run/runtime"; mkdir -p "$RUNTIME" "$ROOT/run/deployment"
check_zip(){ file=$1; expected=$2; got=$(sha256sum "$file" | awk '{print $1}'); [ "$got" = "$expected" ] || { echo "FAIL dependency sha256 $file expected=$expected got=$got" >&2; exit 2; }; }
check_zip "$ROOT/deps/audio_v9_pattern_locator_v0.1-dev5-hotfix1.zip" 6d2716b5f697b9b705214dcc6bd8f93c62b5072111174dd6f3a485334ae5ecd8
check_zip "$ROOT/deps/oorexx_ml_v0.1-dev11.zip" 713c4998c67aed9b526f3e20f7b2f14de4b355939259bff55beebe9133980c79
check_zip "$ROOT/deps/oorexx_ml_graph_v0.1-dev5.zip" 24659562d1e5ca86a08bc3156f838eebd1e320a45e3e8969979fe7dde3b69d40
check_zip "$ROOT/deps/oorexx_foreign_runtime_v0.22.6.zip" 25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465
[ -d "$RUNTIME/oorexx_ml_v0.1-dev11" ] || unzip -q "$ROOT/deps/oorexx_ml_v0.1-dev11.zip" -d "$RUNTIME"
[ -d "$RUNTIME/oorexx_ml_graph_v0.1-dev5" ] || unzip -q "$ROOT/deps/oorexx_ml_graph_v0.1-dev5.zip" -d "$RUNTIME"
[ -d "$RUNTIME/audio_v9_pattern_locator_v0.1-dev5-hotfix1" ] || unzip -q "$ROOT/deps/audio_v9_pattern_locator_v0.1-dev5-hotfix1.zip" -d "$RUNTIME"
[ -d "$RUNTIME/oorexx_foreign_runtime_v0.22.6" ] || unzip -q "$ROOT/deps/oorexx_foreign_runtime_v0.22.6.zip" -d "$RUNTIME"
READY="$ROOT/run/deployment/native.READY.tsv"
cache_ok=0
if [ "${AV9_FORCE_FOREIGN_REBUILD:-0}" != 1 ] && [ "${AV9_FORCE_SPATIAL_REBUILD:-0}" != 1 ] && [ -f "$READY" ]; then
  fr="$RUNTIME/oorexx_foreign_runtime_v0.22.6/build/libforeign_runtime.so"
  sp="$ROOT/run/native/libav9_spatial_provider.so"
  expected_fr=$(awk -F '\t' '$1=="foreign_runtime_sha256" {print $2}' "$READY")
  expected_sp=$(awk -F '\t' '$1=="spatial_provider_sha256" {print $2}' "$READY")
  if [ -f "$fr" ] && [ -f "$sp" ] && [ "$(sha256sum "$fr" | awk '{print $1}')" = "$expected_fr" ] && [ "$(sha256sum "$sp" | awk '{print $1}')" = "$expected_sp" ]; then cache_ok=1; fi
fi
if [ "$cache_ok" -ne 1 ]; then
  "$ROOT/tools/ensure_foreign_runtime.sh" >/dev/null
  "$ROOT/tools/ensure_spatial_native.sh" >/dev/null
  fr="$RUNTIME/oorexx_foreign_runtime_v0.22.6/build/libforeign_runtime.so"
  sp="$ROOT/run/native/libav9_spatial_provider.so"
  {
    printf 'schema\taudio.v9.deployment.native-ready/1\n'
    printf 'foreign_runtime_sha256\t%s\n' "$(sha256sum "$fr" | awk '{print $1}')"
    printf 'spatial_provider_sha256\t%s\n' "$(sha256sum "$sp" | awk '{print $1}')"
  } > "$READY"
fi
printf '%s\n' "$RUNTIME"
