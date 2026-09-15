#!/usr/bin/env bash
set -euo pipefail
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
out="$(rexx ../bin/queuerexx.rex provider-health --json || true)"
python3 - "$out" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d['schema']=='queuerexx.provider_health.v1',d
assert d['provider_count']>=2,d
ids={x['provider'] for x in d['providers']}
assert {'direct','systemd'} <= ids,ids
print('PASS provider-health CLI standardized runner telemetry')
PY
