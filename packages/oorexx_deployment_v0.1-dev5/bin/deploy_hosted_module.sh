#!/bin/sh
set -eu
usage(){ echo "usage: $0 --module DIR --host-root DIR [--activate SCRIPT] [--probe SCRIPT] [--dry-run]" >&2; }
MODULE=''; HOSTROOT=''; ACTIVATE=''; PROBE=''; DRY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --module) MODULE=$2; shift 2;;
    --host-root) HOSTROOT=$2; shift 2;;
    --activate) ACTIVATE=$2; shift 2;;
    --probe) PROBE=$2; shift 2;;
    --dry-run) DRY=1; shift;;
    *) usage; exit 2;;
  esac
done
[ -d "$MODULE" ] && [ -d "$HOSTROOT" ] || { usage; exit 2; }
contract="$MODULE/deployment/hosted-module.tsv"
[ -f "$contract" ] || { echo "FAIL hosted module contract absent: $contract" >&2; exit 3; }
get(){ awk -F '\t' -v k="$1" '$1==k {print $2; exit}' "$contract"; }
id=$(get module_id); hostkind=$(get host_kind); activation=$(get activation_mode); loadprobe=$(get load_probe)
[ -n "$id" ] && [ -n "$hostkind" ] && [ -n "$activation" ] && [ -n "$loadprobe" ] || { echo 'FAIL incomplete hosted-module contract' >&2; exit 3; }
case "$loadprobe" in /*|*..*) echo 'FAIL load_probe must be package-relative' >&2; exit 3;; esac
if [ "$hostkind" = 'oorexx-https' ] && [ "$activation" != 'compose-before-start' ]; then
  echo 'FAIL ooRexx HTTPS routes are startup composition in the current host contract' >&2; exit 4
fi
target="$HOSTROOT/modules/$id"
if [ "$DRY" -eq 1 ]; then
  "$(dirname "$0")/deploy_tree.sh" --source "$MODULE" --target-root "$target" --dry-run
  printf 'PLAN hosted-module=%s host-kind=%s activation=%s\n' "$id" "$hostkind" "$activation"
  exit 0
fi
"$(dirname "$0")/deploy_tree.sh" --source "$MODULE" --target-root "$target"
current="$target/current"
( cd "$current" && sh "$loadprobe" )
printf 'LOADABLE module=%s\n' "$id"
# A staged/loadable module is deliberately not called live.  For HTTPS v0.4.4
# route bindings are immutable once serve() starts, so activation must compose
# the module before the new host generation begins accepting connections.
[ -n "$ACTIVATE" ] || { echo 'STAGED_ONLY no activation script supplied' >&2; exit 10; }
case "$ACTIVATE" in /*|*..*) echo 'FAIL activate script must be host-root-relative' >&2; exit 4;; esac
DEPLOYMENT_MODULE_ROOT="$current" DEPLOYMENT_HOST_ROOT="$HOSTROOT" sh "$HOSTROOT/$ACTIVATE"
printf 'ACTIVATED module=%s\n' "$id"
[ -n "$PROBE" ] || { echo 'ACTIVE_UNPROBED no live probe supplied' >&2; exit 11; }
case "$PROBE" in /*|*..*) echo 'FAIL probe script must be host-root-relative' >&2; exit 4;; esac
DEPLOYMENT_MODULE_ROOT="$current" DEPLOYMENT_HOST_ROOT="$HOSTROOT" sh "$HOSTROOT/$PROBE"
printf 'PROBED_ACTIVE module=%s host=%s\n' "$id" "$HOSTROOT"
