#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); NODE=${1:?node required}; PID="$ROOT/run/$NODE.pid"; RC="$ROOT/run/$NODE.rc"
pid_live_this_boot(){
  [[ -f "$PID" ]] || return 1
  local p mtime now up boot
  p=$(cat "$PID" 2>/dev/null || true); [[ $p =~ ^[0-9]+$ ]] || return 1
  kill -0 "$p" 2>/dev/null || return 1
  mtime=$(stat -c %Y "$PID" 2>/dev/null || echo 0)
  now=$(date +%s); up=$(cut -d. -f1 </proc/uptime); boot=$((now-up))
  (( mtime >= boot ))
}
if [[ -f "$RC" ]]; then x=$(cat "$RC"); [[ "$x" == 0 ]] && echo "COMPLETE $NODE rc=0" || echo "FAILED $NODE rc=$x"; exit 0; fi
if pid_live_this_boot; then echo "RUNNING $NODE pid=$(cat "$PID")"; else echo "UNKNOWN $NODE"; fi
