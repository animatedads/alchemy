#!/bin/sh
# Checks the field kit as published: the tarball's checksum, the checksums of
# every file inside it, and the kit's own selftest run from a scratch unpack.
# Claude (Opus 5.5).  Needs no root.
set -eu
cd "$(dirname "$0")/.."
sha256sum -c xtpd-field-kit-0.1-dev3.tar.gz.sha256
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT HUP INT TERM
tar -C "$W" -xzf xtpd-field-kit-0.1-dev3.tar.gz
(cd "$W/xtpd-0.1-dev2" && sha256sum -c --quiet SHA256SUMS) && echo "PASS every file in the kit matches SHA256SUMS"
env -i HOME="$W" "$W/xtpd-0.1-dev2/bin/selftest" | tail -1
