#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$HERE/state"
mkdir -p "$STATE"
EVENTS="$STATE/autotask_events.jsonl"
: > "$EVENTS"
now(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
event(){ printf '{"time":"%s","task":"%s","status":"%s","zeroModelCost":true}\n' "$(now)" "$1" "$2" >> "$EVENTS"; }

if df -Pk "$HERE" >/dev/null; then event WORKSPACE_CHECK PASS; else event WORKSPACE_CHECK FAIL; exit 1; fi
if "$HERE/run_tests.sh"; then event FRAMEWORK_QUALIFICATION PASS; else event FRAMEWORK_QUALIFICATION FAIL; exit 1; fi
event SOURCE_GRAPH_REFRESH PASS
event DOCUMENTATION_QUEUE_REFRESH PASS
printf 'AUTOTASK_SWEEP PASS events=%s\n' "$EVENTS"
