#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SEARCH_ROOT="$(pwd)"
ROLLUP=""
SERVER_ZIP=""
RUNTIME_DIR=""
OOREXX_HOME_ARG="${OOREXX_HOME:-}"
OOREXX_DEB=""
HOST_ARGS=()

usage(){ cat <<'TXT'
Wire UI Builder Studio v0.11 live launcher

Usage:
  ./run_builder_studio.sh [runtime options] [--port 8765] [--open]

Runtime options (normally auto-detected):
  --runtime-dir DIR    directory containing extracted dependency packages/zips
  --rollup ZIP         oorexxapis roll-up containing Queue Fabric/JS dependencies
  --server-zip ZIP     wire_ui_server_v0.16 zip when not already extracted
  --oorexx-home DIR    ooRexx installation root (default: OOREXX_HOME or /usr/local)
  --oorexx-deb DEB     ooRexx 5.3.0 r13196 .deb; extracted privately if not installed

Host options passed through:
  --host HOST          default 127.0.0.1
  --port PORT          default 8765; use 0 for an ephemeral port
  --open               open the resulting URL with the desktop browser
  --json               keep startup output machine-friendly

No Python application server is used. The live runtime is:
  ooRexx -> WireUIServer v0.16 -> Queue Fabric -> Web Gateway v0.2 -> JS v0.4-dev4
TXT
}

while (($#)); do
  case "$1" in
    --runtime-dir) RUNTIME_DIR="$2"; shift 2;;
    --rollup) ROLLUP="$2"; shift 2;;
    --server-zip) SERVER_ZIP="$2"; shift 2;;
    --oorexx-home) OOREXX_HOME_ARG="$2"; shift 2;;
    --oorexx-deb) OOREXX_DEB="$2"; shift 2;;
    --host|--port) HOST_ARGS+=("$1" "$2"); shift 2;;
    --open|--json) HOST_ARGS+=("$1"); shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
  esac
done

TMP="$(mktemp -d "${TMPDIR:-/tmp}/wire-ui-builder-v08.XXXXXX")"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

candidate_roots=("$ROOT" "$(dirname "$ROOT")" "$SEARCH_ROOT")
[[ -n "$RUNTIME_DIR" ]] && candidate_roots=("$RUNTIME_DIR" "${candidate_roots[@]}")

find_dir(){
  local name="$1" base hit
  for base in "${candidate_roots[@]}"; do
    [[ -d "$base" ]] || continue
    hit="$(find "$base" -maxdepth 5 -type d -name "$name" -exec sh -c 'test -d "$1/src" && printf "%s\n" "$1"' sh {} \; 2>/dev/null | head -1 || true)"
    [[ -n "$hit" ]] && { printf '%s\n' "$hit"; return 0; }
  done
  return 1
}
find_zip(){
  local pattern="$1" base hit
  for base in "${candidate_roots[@]}"; do
    [[ -d "$base" ]] || continue
    hit="$(find "$base" -maxdepth 2 -type f -name "$pattern" -print -quit 2>/dev/null || true)"
    [[ -n "$hit" ]] && { printf '%s\n' "$hit"; return 0; }
  done
  return 1
}
extract_zip(){
  local zip="$1" name="$2"
  local dest="$TMP/$name"
  mkdir -p "$dest"; unzip -q "$zip" -d "$dest"
  local hit="$(find "$dest" -maxdepth 4 -type d -name "$name" -exec sh -c 'test -d "$1/src" && printf "%s\n" "$1"' sh {} \; | head -1)"
  [[ -n "$hit" ]] || { echo "Archive $zip does not contain $name" >&2; return 1; }
  printf '%s\n' "$hit"
}
ensure_rollup(){
  if [[ -z "$ROLLUP" ]]; then ROLLUP="$(find_zip 'oorexxapis*.zip' || true)"; fi
  [[ -n "$ROLLUP" && -f "$ROLLUP" ]] || return 1
}
resolve_pkg(){
  local name="$1" dir zip inner
  dir="$(find_dir "$name" || true)"; [[ -n "$dir" ]] && { printf '%s\n' "$dir"; return; }
  zip="$(find_zip "$name*.zip" || true)"; [[ -n "$zip" ]] && { extract_zip "$zip" "$name"; return; }
  if ensure_rollup; then
    inner="$TMP/$name.zip"
    if unzip -p "$ROLLUP" "current/$name.zip" >"$inner" 2>/dev/null && [[ -s "$inner" ]]; then extract_zip "$inner" "$name"; return; fi
  fi
  echo "Missing exact runtime package $name" >&2
  exit 3
}

SERVER_ROOT="$(find_dir wire_ui_server_v0.16 || true)"
if [[ -z "$SERVER_ROOT" ]]; then
  [[ -n "$SERVER_ZIP" ]] || SERVER_ZIP="$(find_zip 'wire_ui_server_v0.16*.zip' || true)"
  [[ -n "$SERVER_ZIP" && -f "$SERVER_ZIP" ]] || { echo 'Missing wire_ui_server_v0.16. Supply --server-zip or an extracted server directory.' >&2; exit 3; }
  SERVER_ROOT="$(extract_zip "$SERVER_ZIP" wire_ui_server_v0.16)"
fi
QF_ROOT="$(resolve_pkg oorexx_queue_fabric_v0.9-dev4)"
GATEWAY_ROOT="$(resolve_pkg oorexx_queue_fabric_web_gateway_v0.2)"
JS_ROOT="$(resolve_pkg alchemy_wire_ui_js_v0.4-dev4)"
ALCHEMY_ROOT="$(resolve_pkg alchemy_objects_v0.8)"
CRYPTO_ROOT="$(resolve_pkg oorexx_crypto_v0.3)"

if [[ -n "$OOREXX_HOME_ARG" && -x "$OOREXX_HOME_ARG/bin/rexx" ]]; then
  OOR="$OOREXX_HOME_ARG"
elif command -v rexx >/dev/null 2>&1; then
  REXX_BIN="$(command -v rexx)"; OOR="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
else
  [[ -n "$OOREXX_DEB" ]] || OOREXX_DEB="$(find_zip 'oorexx-5.3.0-13196*.deb' || true)"
  [[ -n "$OOREXX_DEB" && -f "$OOREXX_DEB" ]] || { echo 'ooRexx 5.3.0 r13196 not found. Install it or supply --oorexx-deb.' >&2; exit 4; }
  mkdir -p "$TMP/oorexx"; dpkg-deb -x "$OOREXX_DEB" "$TMP/oorexx"; OOR="$TMP/oorexx/usr/local"
fi
[[ -x "$OOR/bin/rexx" ]] || { echo "ooRexx executable not found under $OOR/bin" >&2; exit 4; }

export OOREXX_HOME="$OOR"
export WUIB_BUILDER_ROOT="$ROOT"
export WUIB_REXX="$OOR/bin/rexx"
export WUIB_GATEWAY_ROOT="$GATEWAY_ROOT"
export WUIB_JS_ROOT="$JS_ROOT"
export WIRE_UI_SERVER_SRC="$SERVER_ROOT/src"
export QUEUE_FABRIC_SRC="$QF_ROOT/src"
export ALCHEMY_OBJECTS_SRC="$ALCHEMY_ROOT/src"
export OOREXX_CRYPTO_SRC="$CRYPTO_ROOT/src"
export PATH="$ROOT/src:$ROOT/examples:$ROOT/integration:$SERVER_ROOT/src:$GATEWAY_ROOT/src:$QF_ROOT/src:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$OOR/bin:$PATH"
export REXX_PATH="$ROOT/src:$ROOT/examples:$ROOT/integration:$SERVER_ROOT/src:$GATEWAY_ROOT/src:$QF_ROOT/src:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$OOR/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OOR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

exec node "$ROOT/tools/builder-live-host.mjs" "${HOST_ARGS[@]}"
