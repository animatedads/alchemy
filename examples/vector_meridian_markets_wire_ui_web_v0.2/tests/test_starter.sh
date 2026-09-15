#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -x "$ROOT/start.sh" ]]
"$ROOT/start.sh" --check --preview | grep -q 'starter: PASS mode=preview'
set +e
"$ROOT/start.sh" --check --live >/tmp/vmm-starter-live.out 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]
grep -q 'Live mode requires' /tmp/vmm-starter-live.out
rm -f /tmp/vmm-starter-live.out

log="$(mktemp)"
"$ROOT/start.sh" --preview --port 0 >"$log" 2>&1 &
pid=$!
cleanup(){ kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; rm -f "$log"; }
trap cleanup EXIT
for _ in $(seq 1 100); do
  url="$(sed -n 's/^VMM_WIRE_UI_URL=//p' "$log" | tail -1)"
  [[ -n "$url" ]] && break
  sleep 0.03
done
[[ -n "${url:-}" ]]
node - "$url" <<'NODE'
const url=process.argv[2];
const r=await fetch(url); if(!r.ok) process.exit(2);
const t=await r.text();
if(!t.includes('Vector Meridian Markets') || !t.includes('NON-AUTHORITATIVE PREVIEW')) process.exit(3);
const h=await fetch(new URL('/__health',url)); const j=await h.json();
if(!j.ok || j.mode!=='preview') process.exit(4);
NODE
cleanup
trap - EXIT
echo 'starter script PASS'
