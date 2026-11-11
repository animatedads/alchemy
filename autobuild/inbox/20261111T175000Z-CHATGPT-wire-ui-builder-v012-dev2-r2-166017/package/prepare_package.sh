#!/bin/sh
set -eu
rm -rf prepared source.patch
cat source.patch.* > source.patch
mkdir -p prepared
cd prepared
git apply ../source.patch
cd wire_ui_builder_v0.12-dev2-readiness
sha256sum -c MANIFEST.sha256