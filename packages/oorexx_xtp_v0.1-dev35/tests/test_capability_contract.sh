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
assert d['capabilities']['route_xroute_exchange'] is True
assert d['multicast']['advertised'] is True
assert set(d['multicast']['carriers']) == {'l2','raw36','udp'}
assert d['multicast']['reliable_mode'] == 'go-back-n'
assert d['multicast']['noerr'] is True
assert d['multicast']['receiver_rate_burst_pacing'] is True
print('PASS libxtp multicast stream and receiver RATE/BURST control are implemented and advertised')
# dev26: dev25 shipped CAPABILITIES/DEPENDENCIES labelled dev23 and had dropped
# the named_service block.  Every metadata file must name the same version.
import os
root=os.path.dirname(p)
dep=json.load(open(os.path.join(root,'DEPENDENCIES.json')))
integ=json.load(open(os.path.join(root,'integration.json')))
assert d['capabilities']['named_service'] is True and d['named_service']['first_address_segment'] is True
assert d['version']==dep['version']==integ['package']['version'], (d['version'],dep['version'],integ['package']['version'])
assert integ['publish']['tree']['path'].endswith(d['version']), integ['publish']
assert 'dev26_hardening' in d
print('PASS metadata versions agree ('+d['version']+') and named_service is advertised')
PY
