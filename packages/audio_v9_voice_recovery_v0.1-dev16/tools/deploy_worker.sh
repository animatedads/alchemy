#!/bin/sh
set -eu
usage(){ echo "usage: $0 WORKER HOST LOGIN IDENTITY CORPUS_BASE [TARGET_ROOT] [--start]" >&2; }
[ "$#" -ge 5 ] || { usage; exit 2; }
worker=$1; host=$2; login=$3; identity=$4; corpus=$5; target=${6:-audio_v9_voice_recovery}; start=0
[ "${7:-}" = '--start' ] && start=1
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DEPLOY_HOME=${OOREXX_DEPLOYMENT_HOME:-}
[ -x "$DEPLOY_HOME/bin/deploy_tree.sh" ] || { echo 'FAIL set OOREXX_DEPLOYMENT_HOME to oorexx_deployment_v0.1-dev2' >&2; exit 2; }
"$DEPLOY_HOME/bin/deploy_tree.sh" --source "$ROOT" --target-root "$target" --host "$host" --user "$login" --identity "$identity"
dest="$login@$host"
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -i "$identity" "$dest" sh -s -- "$target" "$corpus" "$worker" "$start" <<'EOS'
set -eu
root=$1; corpus=$2; worker=$3; start=$4
cd "$root/current"
./tools/check_worker_ready.sh "$corpus"
if [ "$start" -eq 1 ]; then
  ./tools/run_worker.sh "$worker" "$corpus" "./run/workers/$worker" spatial
else
  echo "READY_NOT_STARTED worker=$worker"
fi
EOS
