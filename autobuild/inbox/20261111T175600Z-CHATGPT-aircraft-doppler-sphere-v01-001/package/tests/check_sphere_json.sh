#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for f in profiles/*.json packs/aircraft-acoustic-geolocation/*.json integration.json; do
  python3 -m json.tool "$f" > /dev/null
done
python3 - <<'PY'
import glob, json
sphere = json.load(open('packs/aircraft-acoustic-geolocation/00-sphere.json'))
assert sphere['kind'] == 'sphere'
articles = [json.load(open(p)) for p in glob.glob('packs/aircraft-acoustic-geolocation/0[1-9]*.json')]
ids = {a['id'] for a in articles}
assert all(a['kind']=='article' and a['sphere']==sphere['id'] for a in articles)
assert set(sphere['start_here']) == ids
profile = json.load(open('profiles/aircraft-acoustic-geolocation.json'))
assert profile['id'] == sphere['id']
assert 'packs/aircraft-acoustic-geolocation' in profile['packs']
print('PASS sphere JSON identities, entrypoints and article provenance bounds')
PY
