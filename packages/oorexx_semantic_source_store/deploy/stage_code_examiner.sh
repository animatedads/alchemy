#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 PACKAGE_ROOT ALCHEMY_WIRE_UI_JS_ROOT DESTINATION" >&2
  exit 2
}

[[ $# -eq 3 ]] || usage
package_root=$(cd "$1" && pwd)
wire_js_root=$(cd "$2" && pwd)
dest=$3

[[ -f "$package_root/web/index.html" ]] || { echo "missing package web/index.html" >&2; exit 2; }
[[ -f "$wire_js_root/src/index.js" ]] || { echo "expected Alchemy Wire UI JS src/index.js" >&2; exit 2; }

rm -rf "$dest"
mkdir -p "$dest/vendor/alchemy-wire-ui"
cp -a "$package_root/web/." "$dest/"
rm -f "$dest/service-descriptor.example.json" "$dest/config.example.mjs.deprecated"
cp -a "$wire_js_root/src" "$dest/vendor/alchemy-wire-ui/"

# Deliberately do not manufacture service-descriptor here.  It contains the
# deployment-specific authorised Queue Fabric endpoint and must be generated
# from the running Wire host/gateway values.

echo "staged Examiner browser at $dest"
echo "next: generate service-descriptor with deploy/generate_service_descriptor.sh"
