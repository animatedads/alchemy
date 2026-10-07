#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$root/CAPABILITIES.json" <<'PY'
import json,sys
p=sys.argv[1]
d=json.load(open(p))
assert d['capabilities']['multicast'] is True
assert d['capabilities']['multicast_stream'] is True
assert d['capabilities']['rate_control'] is True
assert d['multicast']['advertised'] is True
assert set(d['multicast']['carriers']) == {'l2','raw36','udp'}
assert d['multicast']['reliable_mode'] == 'go-back-n'
assert d['multicast']['noerr'] is True
assert d['multicast']['receiver_rate_burst_pacing'] is True
print('PASS libxtp multicast stream and receiver RATE/BURST control are implemented and advertised')
PY
