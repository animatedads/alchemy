#!/usr/bin/env bash
set -euo pipefail

base=${1:?usage: smoke_code_examiner.sh https://HOST/code-examiner}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl --fail --silent --show-error --location "$base/" > "$tmp/index.html"
curl --fail --silent --show-error --location "$base/service-descriptor" > "$tmp/service.json"
curl --fail --silent --show-error --location "$base/bootstrap.mjs" > "$tmp/bootstrap.mjs"
curl --fail --silent --show-error --location "$base/vendor/alchemy-wire-ui/src/index.js" > "$tmp/wire-index.js"

python3 - "$tmp" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
html = (root/'index.html').read_text()
boot = (root/'bootstrap.mjs').read_text()
desc = json.loads((root/'service.json').read_text())
required_actions = {
    'CODE.CLASS.INSPECT','CODE.COMPARE','METHOD.REQUIREMENT.CREATE','METHOD.NOTE.CREATE',
    'RESOURCE.UPLOAD','CODE.PACKAGE.REQUEST','CODE.TEST.REQUEST','WORK.ACCEPT','WORK.REFUSE',
    'MODULE.REQUIREMENT.CREATE','DEPLOYMENT.PACKAGE.REQUEST','BRANCH.CLASSIFY','BRANCH.PROTECT',
    'BRANCH.CONFLICT.RESOLVE','BRANCH.PACKAGE.REQUEST','CODE.GOTO_DEFINITION','CODE.FIND_USES',
    'CODE.CALLERS','CODE.CALLEES','CODE.REFERENCE.EXPLAIN','CODE.CLASS.SURFACE','CODE.CLASS.OVERRIDES'
}
missing = sorted(a for a in required_actions if f'data-semantic-action="{a}"' not in html)
if missing: raise SystemExit('missing visible Examiner actions: '+', '.join(missing))
if 'data-role="class-inspection-view"' not in html or 'data-default-view="true"' not in html:
    raise SystemExit('condensed class inspection is not the rendered default')
if desc.get('authenticationRequired') is not True:
    raise SystemExit('service descriptor does not require authentication')
auth = desc.get('authentication') or {}
if auth.get('principalSource') != 'verified-session' or auth.get('session') != 'opaque-bearer':
    raise SystemExit('service descriptor security authority is incomplete')
for a in ['WORK.ACCEPT','WORK.REFUSE','BRANCH.CLASSIFY','BRANCH.PROTECT','BRANCH.CONFLICT.RESOLVE']:
    if a not in auth.get('privilegedStepUp',[]): raise SystemExit('missing step-up '+a)
if not str(desc.get('websocketUrl','')).startswith('wss://'):
    raise SystemExit('production smoke requires wss://')
if "mount.innerHTML = ''" in boot:
    raise SystemExit('bootstrap can erase the Examiner shell')
print('EXAMINER DEPLOYED ROUTE STATIC/SECURITY SMOKE: PASS')
print('NOTE: this smoke proves served assets + descriptor contract, not authenticated Wire action round-trip.')
PY
