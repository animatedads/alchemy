#!/usr/bin/env bash
set -euo pipefail
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
r=pathlib.Path(sys.argv[1]); p=r/'packs/semantic-source-control'
for f in list(p.glob('*.json'))+[r/'profiles/semantic-source-control.json',r/'integration.json']:
    json.loads(f.read_text())
services=[]
for f in p.glob('*-service-*.json'):
    o=json.loads(f.read_text()); services.append(o)
assert len(services)==6, len(services)
expected={f'source.semantic.{x}' for x in ('status','identify','compare','impact','source','proposals')}
assert {o['capabilities'][0] for o in services}==expected
for o in services:
    cap=o['capabilities'][0]; op=cap.rsplit('.',1)[-1]
    assert o['implementation']==f'external.semantic-source-control.machine.{op}'
policy=json.loads((p/'01-access-policy-semantic-source-control-access.json').read_text())
denied={rule['resource'] for rule in policy['rules'] if rule['effect']=='deny'}
assert 'capability:source.semantic.accept' in denied
assert 'capability:source.semantic.proposal.decide' in denied
corpus=json.loads((p/'10-corpus-ssc.interface.json').read_text())
read={x['capability']:x for x in corpus['records'] if x.get('topic')=='gopher-capability'}
assert set(read)==expected and all(x['state']=='EXECUTABLE_READ_ONLY' for x in read.values())
planned={x['capability'] for x in corpus['records'] if x.get('topic')=='gopher-gap' and x.get('state')=='PLANNED'}
assert {'source.semantic.accept','source.semantic.proposal.decide'} <= planned
print('PASS SEMANTIC SOURCE CONTROL GOPHER SPHERE v0.2-dev1 static contract')
PY
if [[ -n "${GOPHER_SSC:-}" && -n "${LLM_GOPHER_ENV:-}" && -f "${SPHERE_ZIP:-}" ]]; then
  "$GOPHER_SSC" sphere load semantic-source-control --override "$SPHERE_ZIP" >/tmp/ssc-sphere-load.json
  grep -q 'ACTIVATED' /tmp/ssc-sphere-load.json
  "$GOPHER_SSC" --profile semantic-source-control find source.semantic.status --sphere semantic-source-control >/tmp/ssc-find.json
  grep -q 'external.semantic-source-control.machine.status' /tmp/ssc-find.json
  "$GOPHER_SSC" --profile semantic-source-control describe source.semantic.status --sphere semantic-source-control >/tmp/ssc-desc.json
  grep -q 'accepted SSC component' /tmp/ssc-desc.json
  echo 'PASS SEMANTIC SOURCE CONTROL GOPHER SPHERE v0.2-dev1 live adapter discovery'
else
  echo 'SKIP live adapter discovery: set GOPHER_SSC, LLM_GOPHER_ENV and SPHERE_ZIP'
fi
