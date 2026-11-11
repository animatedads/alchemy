#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 -m json.tool packs/spash-ogg-seek/00-sphere.json >/dev/null
python3 -m json.tool packs/spash-ogg-seek/01-access-policy.json >/dev/null
python3 -m json.tool packs/spash-ogg-seek/02-article-ogg.seek.start.json >/dev/null
python3 -m json.tool packs/spash-ogg-seek/03-article-ogg.seek.storage.json >/dev/null
python3 -m json.tool profiles/spash-ogg-seek.json >/dev/null
echo 'PASS Gopher sphere JSON parse'
