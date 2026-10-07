#!/usr/bin/env bash
set -euo pipefail

# Complete environment deployment/qualification script for the Semantic Source
# Code Examiner.  This script does not edit SSC, Wire UI, or backend source.
# It stages the exact browser runtime, writes deployment-specific configuration,
# atomically installs the site, and verifies the live HTTPS route.

usage() {
  cat >&2 <<'USAGE'
usage: deploy_code_examiner_environment.sh \
  --package-root /path/to/ssc_dev22 \
  --wire-js-root /path/to/alchemy_wire_ui_js_v0.4-dev4 \
  --install-root /srv/code-examiner \
  --base-url https://HOST/code-examiner \
  --websocket-url wss://HOST/wire-ui \
  --outbound-queue QUEUE_NAME

Optional:
  --reload-cmd 'systemctl reload nginx'
  --health-url https://HOST/health
  --expected-class TEXT     Require this text after an authenticated live render.
  --browser chromium        Browser executable for real rendered-page qualification.

Authentication is deliberately not invented here.  The deployed HTTPS/WSS
endpoint must supply its existing authenticated principal/session boundary.
USAGE
  exit 2
}

package_root=''
wire_js_root=''
install_root=''
base_url=''
websocket_url=''
outbound_queue=''
reload_cmd=''
health_url=''
expected_class=''
browser='chromium'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-root) package_root=$2; shift 2 ;;
    --wire-js-root) wire_js_root=$2; shift 2 ;;
    --install-root) install_root=$2; shift 2 ;;
    --base-url) base_url=${2%/}; shift 2 ;;
    --websocket-url) websocket_url=$2; shift 2 ;;
    --outbound-queue) outbound_queue=$2; shift 2 ;;
    --reload-cmd) reload_cmd=$2; shift 2 ;;
    --health-url) health_url=$2; shift 2 ;;
    --expected-class) expected_class=$2; shift 2 ;;
    --browser) browser=$2; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n $package_root && -n $wire_js_root && -n $install_root && -n $base_url && -n $websocket_url && -n $outbound_queue ]] || usage
[[ $base_url == https://* ]] || { echo 'base URL must use https://' >&2; exit 2; }
[[ $websocket_url == wss://* ]] || { echo 'websocket URL must use wss://' >&2; exit 2; }
[[ -f "$package_root/web/index.html" ]] || { echo 'missing package web/index.html' >&2; exit 2; }
[[ -f "$wire_js_root/src/index.js" ]] || { echo 'missing Alchemy Wire UI JS src/index.js' >&2; exit 2; }

stage=$(mktemp -d)
probe=$(mktemp -d)
cleanup() { rm -rf "$stage" "$probe"; }
trap cleanup EXIT

# 1. Stage exact browser files.  No legacy reader is copied.
cp -a "$package_root/web/." "$stage/"
rm -f "$stage/service-descriptor.example.json" "$stage/config.example.mjs.deprecated"
mkdir -p "$stage/vendor/alchemy-wire-ui"
cp -a "$wire_js_root/src" "$stage/vendor/alchemy-wire-ui/"

# 2. Deployment-specific service descriptor.  No identity is accepted from JS.
cat > "$stage/service-descriptor" <<JSON
{
  "schema": "semantic-source.code-examiner.service/1",
  "applicationId": "SSC-CODE-EXAMINER",
  "accessPointId": "WEB",
  "source": "SSC.CODE.EXAMINER.WEB",
  "websocketUrl": "$websocket_url",
  "outboundQueue": "$outbound_queue",
  "authenticationRequired": true,
  "authentication": {
    "scheme": "SSC-SIGNED-CHALLENGE-1",
    "session": "opaque-bearer",
    "principalSource": "verified-session",
    "privilegedStepUp": [
      "WORK.ACCEPT",
      "WORK.REFUSE",
      "BRANCH.CLASSIFY",
      "BRANCH.PROTECT",
      "BRANCH.CONFLICT.RESOLVE"
    ]
  }
}
JSON

# 3. Fail before install if this is not the full Examiner.
python3 - "$stage" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
html=(root/'index.html').read_text()
boot=(root/'bootstrap.mjs').read_text()
desc=json.loads((root/'service-descriptor').read_text())
required=[
'CODE.CLASS.INSPECT','CODE.COMPARE','METHOD.REQUIREMENT.CREATE','METHOD.NOTE.CREATE',
'RESOURCE.UPLOAD','CODE.PACKAGE.REQUEST','CODE.TEST.REQUEST','WORK.ACCEPT','WORK.REFUSE',
'MODULE.REQUIREMENT.CREATE','DEPLOYMENT.PACKAGE.REQUEST','BRANCH.CLASSIFY','BRANCH.PROTECT',
'BRANCH.CONFLICT.RESOLVE','BRANCH.PACKAGE.REQUEST','CODE.GOTO_DEFINITION','CODE.FIND_USES',
'CODE.CALLERS','CODE.CALLEES','CODE.REFERENCE.EXPLAIN','CODE.CLASS.SURFACE','CODE.CLASS.OVERRIDES'
]
missing=[x for x in required if f'data-semantic-action="{x}"' not in html]
if missing: raise SystemExit('not installing incomplete Examiner: '+', '.join(missing))
for marker in ['data-role="class-inspection-view"','data-default-view="true"','data-wire-slot="class_tree"','data-wire-slot="class_method_summary"']:
    if marker not in html: raise SystemExit('missing default condensed class view: '+marker)
if "mount.innerHTML = ''" in boot: raise SystemExit('bootstrap can erase Examiner UI')
if not desc.get('authenticationRequired'): raise SystemExit('authentication not required')
auth=desc.get('authentication') or {}
if auth.get('principalSource')!='verified-session': raise SystemExit('principal is not session-authoritative')
if auth.get('session')!='opaque-bearer': raise SystemExit('opaque bearer session not required')
print('PREINSTALL EXAMINER CONTRACT: PASS')
PY

# 4. Atomic site replacement.  Preserve previous deployment for rollback.
parent=$(dirname "$install_root")
name=$(basename "$install_root")
mkdir -p "$parent"
new="$parent/.${name}.new.$$"
old="$parent/.${name}.previous"
rm -rf "$new"
cp -a "$stage" "$new"
if [[ -e "$install_root" ]]; then
  rm -rf "$old"
  mv "$install_root" "$old"
fi
mv "$new" "$install_root"

if [[ -n $reload_cmd ]]; then
  bash -lc "$reload_cmd"
fi

# 5. Optional service health, then live route assets.
if [[ -n $health_url ]]; then
  curl --fail --silent --show-error --location "$health_url" >/dev/null
  echo 'SERVICE HEALTH: PASS'
fi
curl --fail --silent --show-error --location "$base_url/" > "$probe/index.html"
curl --fail --silent --show-error --location "$base_url/app.css" > "$probe/app.css"
curl --fail --silent --show-error --location "$base_url/bootstrap.mjs" > "$probe/bootstrap.mjs"
curl --fail --silent --show-error --location "$base_url/service-descriptor" > "$probe/service-descriptor"
curl --fail --silent --show-error --location "$base_url/vendor/alchemy-wire-ui/src/index.js" > "$probe/wire-index.js"

python3 - "$probe" "$websocket_url" "$outbound_queue" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]); ws=sys.argv[2]; q=sys.argv[3]
html=(root/'index.html').read_text(); desc=json.loads((root/'service-descriptor').read_text())
assert 'Semantic Source Code Examiner' in html
assert 'data-role="class-inspection-view"' in html
assert desc['websocketUrl']==ws
assert desc['outboundQueue']==q
assert desc['authenticationRequired'] is True
print('LIVE ROUTE ASSET/DESCRIPTOR: PASS')
PY

# 6. Real browser render.  This verifies the human UI survives JavaScript startup;
# it does not call a static HTML grep a "UI test".
if command -v "$browser" >/dev/null 2>&1; then
  profile="$probe/chrome-profile"
  mkdir -p "$profile"
  "$browser" --headless --no-sandbox --disable-gpu --disable-dev-shm-usage \
    --user-data-dir="$profile" --window-size=1600,1000 --virtual-time-budget=5000 \
    --dump-dom "$base_url/" > "$probe/rendered.html" 2>"$probe/browser.stderr" || {
      cat "$probe/browser.stderr" >&2
      echo 'real browser qualification failed' >&2
      exit 1
    }
  python3 - "$probe/rendered.html" "$expected_class" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text(errors='replace'); expected=sys.argv[2]
for marker in ['Semantic Source Code Examiner','class-inspection-view','Exact source / method bodies','Requirements &amp; notes','Branches','Work review']:
    if marker not in s: raise SystemExit('rendered browser DOM missing '+marker)
if expected and expected not in s:
    raise SystemExit('authenticated live class evidence not rendered: '+expected)
print('REAL BROWSER EXAMINER RENDER: PASS')
PY
else
  echo "REAL BROWSER EXAMINER RENDER: SKIP ($browser not installed)" >&2
fi

cat <<EOF2
CODE EXAMINER ENVIRONMENT DEPLOYMENT: PASS
URL: $base_url/
INSTALL: $install_root
ROLLBACK COPY: $old

Important: if --expected-class was omitted, this proves the real Examiner UI and
Wire bootstrap are deployed, but not an authenticated semantic data round-trip.
For full production qualification rerun with an authenticated browser context
and --expected-class naming a class known to the authoritative SSC store.
EOF2
