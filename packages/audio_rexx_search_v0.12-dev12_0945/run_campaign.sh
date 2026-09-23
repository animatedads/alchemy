#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TP00006_SOURCE=${TP00006_SOURCE:-/srv/space/fcpaphos/20231010_093912_tp00006_original.ogg}
TP00023_SOURCE=${TP00023_SOURCE:-/srv/space/fcpaphos/20231010_090927_tp00023_original.ogg}
TP00024_SOURCE=${TP00024_SOURCE:-/srv/space/fcpaphos/20231010_094521_tp00024_original.ogg}
export TP00006_SOURCE TP00023_SOURCE TP00024_SOURCE
MODE=${1:---qualification}
export AUDIO_POOL_THREAD_ID=${AUDIO_POOL_THREAD_ID:-campaign-0945-quality-v1}
export AUDIO_POOL_AUTO_OBSERVE=${AUDIO_POOL_AUTO_OBSERVE:-1}
case "$MODE" in
  --qualification) exec "$ROOT/deploy_all.sh" --qualification --reset-state ;;
  --full) exec "$ROOT/deploy_all.sh" --full ;;
  --full-fresh) exec "$ROOT/deploy_all.sh" --full --reset-state ;;
  *) echo 'usage: ./run_campaign.sh [--qualification|--full|--full-fresh]' >&2; exit 2 ;;
esac
