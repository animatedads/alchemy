#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -x "$ROOT/start.sh" ]]
"$ROOT/start.sh" --check --preview | grep -q 'starter: PASS mode=preview'
if [[ -n "${AJI_OOREXX:-}" ]]; then
  args=(--check --live --rexx "$AJI_OOREXX")
  [[ -n "${AJI_OOREXX_LIB:-}" ]] && args+=(--rexx-lib "$AJI_OOREXX_LIB")
  "$ROOT/start.sh" "${args[@]}" | grep -q 'starter: PASS mode=live'
else
  echo 'AJI live starter prerequisite check: SKIP (AJI_OOREXX not set)'
fi
log="$(mktemp)"; "$ROOT/start.sh" --preview --port 0 >"$log" 2>&1 & pid=$!
cleanup(){ kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; rm -f "$log"; }; trap cleanup EXIT
for _ in $(seq 1 100); do url="$(sed -n 's/^AJI_WIRE_UI_URL=//p' "$log" | tail -1)"; [[ -n "$url" ]] && break; sleep .03; done
[[ -n "${url:-}" ]]
node - "$url" <<'NODE'
const url=process.argv[2];const r=await fetch(url);if(!r.ok)process.exit(2);const t=await r.text();if(!t.includes('All Japan Insurance')||!t.includes('NON-AUTHORITATIVE FRONT-END FIXTURE'))process.exit(3);const h=await fetch(new URL('/__health',url));const j=await h.json();if(!j.ok||j.mode!=='preview'||j.siteId!=='ALL_JAPAN_INSURANCE')process.exit(4);
NODE
cleanup; trap - EXIT
echo 'AJI starter script PASS'
