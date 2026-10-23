#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PATCH="$HERE/source.patch"
EXPECTED_PATCH_SHA256="ee8dbff8acc8df3e812f16dbe728335983bcee97d0669499406929dfc24b709f"
printf '%s  %s\n' "$EXPECTED_PATCH_SHA256" "$PATCH" | sha256sum -c -
rm -rf "$HERE/prepared"
mkdir -p "$HERE/prepared"
cd "$HERE"
git apply --check --directory=prepared "$PATCH"
git apply --directory=prepared "$PATCH"
test -f "$HERE/prepared/wire_ui_builder_v0.6/README.md"
test -f "$HERE/prepared/wire_ui_builder_v0.6/MANIFEST.sha256"