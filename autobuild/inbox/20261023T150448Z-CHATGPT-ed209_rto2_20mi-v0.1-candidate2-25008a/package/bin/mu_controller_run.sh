#!/usr/bin/env bash
# Runs ON the owning MU, using its commissioned QF/XTP native client. SSH is never used to run code inside the MI.
set -euo pipefail
umask 077
[[ $# -ge 2 && $# -le 3 ]] || { echo 'usage: mu_controller_run.sh RUN_ID MI_ID [COUNT]' >&2; exit 64; }
RUN_ID=$1 NODE=$2 COUNT=${3:-1000}
# Optional root-owned nonsecret site settings for SSH-invoked controller commands.
SITE_ENV=${GRID_RTO2_SITE_ENV:-/etc/rexxos-grid/rto2-test.env}
if [[ -f $SITE_ENV ]]; then
  [[ ! -L $SITE_ENV ]] || { echo "refusing symlink site config" >&2; exit 65; }
  # shellcheck disable=SC1090
  source "$SITE_ENV"
fi
[[ $RUN_ID =~ ^[A-Za-z0-9._-]{1,80}$ && $NODE =~ ^MN[12]-ED209[A-Z]$ && $COUNT =~ ^[0-9]+$ && $COUNT -ge 1 && $COUNT -le 1000 ]] || exit 64
: "${GRID_AUTHORITY:?must select the installed PRIVATE commissioning authority}"
: "${GRID_PACKAGE_ROOT:?must select the verified Grid package root}"
: "${GRID_RTO2_APPROVED_EPOCH:?must supply RTO2 test ACTIVE epoch issued by local controller}"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[[ -d $GRID_AUTHORITY && -d $GRID_PACKAGE_ROOT ]] || exit 66
NENV="$GRID_AUTHORITY/nodes/$NODE/node.env"
[[ -r $NENV ]] || { echo 'node not commissioned on this MU' >&2; exit 67; }
# shellcheck disable=SC1090
source "$NENV"
[[ $GRID_NODE_ID == "$NODE" ]] || exit 67
[[ -n ${GRID_MU_ID:-} && -n ${GRID_MU_KEY_HEX:-} && -n ${GRID_NODE_MAC:-} && -n ${GRID_ROUTE_ID:-} ]] || exit 67
MU=$GRID_MU_ID
[[ -r "$GRID_AUTHORITY/mus/$MU/mu.env" ]] || exit 68
ROUTES="$GRID_AUTHORITY/mus/$MU/xtp.routes.tsv"
[[ -r $ROUTES ]] || exit 68
# This operation requires controller-to-MI trust installed separately and an MI image containing the work handler.
QF_HELPER=${GRID_RTO2_HELPER:-$GRID_PACKAGE_ROOT/xtp/qf-xtp-rpc}
[[ -x $QF_HELPER ]] || exit 69
REXX_BIN=${GRID_REXX:-/usr/local/bin/rexx}
[[ -x $REXX_BIN ]] || exit 69
export QF_XTP_PACKAGE_ROOT=$GRID_PACKAGE_ROOT
# Domain-separated RTO2 work key: never reuse MI registration key as application channel key.
export GRID_RTO2_KEY_HEX=$(python3 "$SCRIPT_DIR/../ops/derive_work_key.py" --authority "$GRID_AUTHORITY" --mi "$NODE")
export REXX_PATH="$GRID_PACKAGE_ROOT/xtp/upstream-dev18/rexx:$GRID_PACKAGE_ROOT/deps/socket-provider-dev14/src:$GRID_PACKAGE_ROOT/deps/qf:$GRID_PACKAGE_ROOT/deps:$GRID_PACKAGE_ROOT/deps/alchemy:$GRID_PACKAGE_ROOT/rto2${REXX_PATH:+:$REXX_PATH}"
RAW=$(mktemp); trap 'rm -f "$RAW"' EXIT
"$REXX_BIN" "$SCRIPT_DIR/../rexx/mu-rto2-submit.rex" "$RUN_ID" "$NODE" "$MU" "$COUNT" "$GRID_RTO2_APPROVED_EPOCH" "$GRID_NODE_MAC" "$GRID_ROUTE_ID" "$ROUTES" "$QF_HELPER" @env > "$RAW" || { echo "native XTP RTO2 execution failed for $NODE" >&2; exit 70; }
unset GRID_RTO2_KEY_HEX GRID_MU_KEY_HEX
STORE=${GRID_RTO2_STORE:-/var/lib/rexxos-grid/$MU/rto2-job-results}
python3 "$SCRIPT_DIR/controller_commit.py" --run "$RUN_ID" --mi "$NODE" --mu "$MU" --n "$COUNT" --epoch "$GRID_RTO2_APPROVED_EPOCH" --store "$STORE" < "$RAW"
