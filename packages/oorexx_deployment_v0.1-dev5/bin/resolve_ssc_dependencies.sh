#!/bin/sh
set -eu
SELF=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SELF/.." && pwd)
REXX=${OOREXX_REXX:-rexx}
ssc_root=${SSC_ROOT:-}
consumer=
out=
entries_tmp=$(mktemp "${TMPDIR:-/tmp}/deploy-entries.XXXXXX")
providers_tmp=$(mktemp "${TMPDIR:-/tmp}/deploy-providers.XXXXXX")
trap 'rm -f "$entries_tmp" "$providers_tmp"' EXIT HUP INT TERM
: >"$entries_tmp"; : >"$providers_tmp"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ssc-root) [ "$#" -ge 2 ] || exit 2; ssc_root=$2; shift 2 ;;
    --consumer) [ "$#" -ge 2 ] || exit 2; consumer=$2; shift 2 ;;
    --entry) [ "$#" -ge 2 ] || exit 2; printf '%s\n' "$2" >>"$entries_tmp"; shift 2 ;;
    --provider) [ "$#" -ge 2 ] || exit 2; printf '%s\n' "$2" >>"$providers_tmp"; shift 2 ;;
    --out) [ "$#" -ge 2 ] || exit 2; out=$2; shift 2 ;;
    *) echo "FAIL unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -n "$ssc_root" ] || { echo 'FAIL --ssc-root or SSC_ROOT required' >&2; exit 2; }
[ -n "$consumer" ] || { echo 'FAIL --consumer required' >&2; exit 2; }
[ -s "$entries_tmp" ] || { echo 'FAIL at least one --entry required' >&2; exit 2; }
[ -n "$out" ] || { echo 'FAIL --out required' >&2; exit 2; }
[ -f "$ssc_root/src/SemanticSourceControl.cls" ] || { echo 'FAIL SemanticSourceControl.cls not found under SSC root' >&2; exit 3; }
verify_manifest() {
  d=$1
  if [ -f "$d/MANIFEST.sha256" ]; then
    (cd "$d" && sha256sum -c MANIFEST.sha256 >/dev/null) || { echo "FAIL manifest verification: $d" >&2; exit 4; }
  fi
}
verify_manifest "$consumer"
while IFS= read -r d; do [ -n "$d" ] && verify_manifest "$d"; done <"$providers_tmp"
export DEPLOY_CONSUMER_ROOT=$consumer
export DEPLOY_ENTRY_FILE=$entries_tmp
export DEPLOY_PROVIDER_FILE=$providers_tmp
export DEPLOY_DEPENDENCY_OUT=$out
export REXX_PATH="$ROOT/src:$ssc_root/src:$ssc_root${REXX_PATH:+:$REXX_PATH}"
exec "$REXX" "$SELF/resolve_ssc_dependencies.rex"
