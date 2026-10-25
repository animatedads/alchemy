#!/usr/bin/env bash
# Disposable Storage Fabric catalogue smoke; never edits the installed authority.
set -euo pipefail
if [ "$#" -ne 1 ]; then echo "usage: $0 /absolute/path/to/existing-video" >&2; exit 2; fi
SOURCE=$1
if [ ! -f "$SOURCE" ] || [ -L "$SOURCE" ]; then echo "video must be regular file, not symlink" >&2; exit 3; fi
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ed209-storage-catalogue-XXXXXXXX")
trap 'rm -rf -- "$WORK"' EXIT
NODE=${STORAGE_NODE_ID:-ed209c}
STORAGE_LOCAL_SAFETY=UNKNOWN "$ROOT/bin/storage" --state-root "$WORK/state" --node "$NODE" \
  add "$SOURCE" --virtual /customers/initech/tps/smoke.webm --tag pilot --meta customer=Initech \
  --format json > "$WORK/add.json"
STORAGE_LOCAL_SAFETY=UNKNOWN "$ROOT/bin/storage" --state-root "$WORK/state" --node "$NODE" \
  locate /customers/initech/tps/smoke.webm --format json > "$WORK/locate.json"
python3 - "$SOURCE" "$WORK/add.json" "$WORK/locate.json" <<'PYTHON'
import hashlib,json,pathlib,sys
src,a,l=sys.argv[1:]
data=pathlib.Path(src).read_bytes()
expected='sha256:'+hashlib.sha256(data).hexdigest()
add=json.load(open(a))['files'][0]
loc=json.load(open(l))['files'][0]
assert add['id']==expected and loc['id']==expected
assert add['size_bytes']==len(data) and loc['size_bytes']==len(data)
assert any(x['path']=='/customers/initech/tps/smoke.webm' for x in loc['virtual_paths'])
print('PASS ed209 isolated Storage catalogue video pin',expected,'bytes='+str(len(data)))
PYTHON
